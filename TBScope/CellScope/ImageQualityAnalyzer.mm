//
//  ImageQualityAnalyzer.m
//  TBScope
//
//  Created by Frankie Myers on 6/18/14.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "ImageQualityAnalyzer.h"
#import "TBScopeCamera.h"
#include <opencv2/imgproc/imgproc.hpp>
#include <vector>       // std::vector
#include <algorithm>    // std::sort
#include <numeric>      // accumulate

@implementation ImageQualityAnalyzer

static int const kMinBoundaryThreshold = 70.0;  // The minimum boundaryScore at which we consider an image to be a boundary
static float const kMinContentThreshold = 1.80;   // The minimum contentScore at which we consider an image to have content

using namespace cv;

+(IplImage *)createIplImageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    IplImage *iplimage = 0;
    IplImage *cropped = 0;
    
    if (sampleBuffer) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        // get information of the image in the buffer
        uint8_t *bufferBaseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        size_t bufferWidth = CVPixelBufferGetWidth(imageBuffer);
        size_t bufferHeight = CVPixelBufferGetHeight(imageBuffer);
        
        // create IplImage
        if (bufferBaseAddress) {
            iplimage = cvCreateImage(cvSize((int)bufferWidth, (int)bufferHeight), IPL_DEPTH_8U, 4);
            memcpy(iplimage->imageData, (char*)bufferBaseAddress, iplimage->imageSize);
            
            //crop it
            cvSetImageROI(iplimage, cvRect(iplimage->width/2-(CROP_WINDOW_SIZE/2), iplimage->height/2-(CROP_WINDOW_SIZE/2), CROP_WINDOW_SIZE, CROP_WINDOW_SIZE));
            cropped = cvCreateImage(cvGetSize(iplimage),
                                    iplimage->depth,
                                    iplimage->nChannels);

            cvCopy(iplimage, cropped, NULL);
            cvResetImageROI(iplimage);
        }
        
        // release memory
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    }
    else
        NSLog(@"No sampleBuffer!!");
    
    cvReleaseImage(&iplimage);
    
    return cropped;
}

//convert iOS image to OpenCV image.
//TODO: look into what this is doing with color images
+ (cv::Mat)cvMatWithImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    cv::Mat cvMat;
    
    
    if (CGColorSpaceGetModel(colorSpace) == kCGColorSpaceModelRGB) { // 3 channels
        cvMat = cv::Mat(rows, cols, CV_8UC3);
    } else if (CGColorSpaceGetModel(colorSpace) == kCGColorSpaceModelMonochrome) { // 1 channel
        cvMat = cv::Mat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    }
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNone |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    //CGColorSpaceRelease(colorSpace); //intermitted crashes can result when you release CG objects NOT created with functions that have Create or Copy in the name (as with this one)
    
    
    return cvMat;
}

+ (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer

{
    
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // Lock the base address of the pixel buffer
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    
    
    // Get the number of bytes per row for the pixel buffer
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    
    
    // Get the number of bytes per row for the pixel buffer
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    // Get the pixel buffer width and height
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    
    
    // Create a device-dependent RGB color space
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    
    
    // Create a bitmap graphics context with the sample buffer data
    
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    // Create a Quartz image from the pixel data in the bitmap graphics context
    
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    
    // Unlock the pixel buffer
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    
    
    // Free up the context and color space
    
    CGContextRelease(context);
    
    CGColorSpaceRelease(colorSpace);
    
    
    
    // Create an image object from the Quartz image
    
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    
    
    // Release the Quartz image
    
    CGImageRelease(quartzImage);
    
    
    
    return (image);
    
}

double entropy(Mat *img)
{
    int numBins = 256, nPixels;
    float range[] = {0, 255};
    double imgEntropy = 0 , prob;
    const float* histRange = { range };
    Mat histValues;
    
    //calculating the histogram
    calcHist(img, 1, 0, Mat(), histValues, 1, &numBins, &histRange, true, true );
    
    nPixels = sum(histValues)[0];
    
    
    for(int i = 1; i < numBins; i++)
    {
        prob = histValues.at<double>(i)/nPixels;
        if(prob < FLT_EPSILON)
            continue;
        imgEntropy += prob*(log(prob)/log(2));
        
    }
    
    return (0-imgEntropy);
}
// OpenCV port of 'LAPM' algorithm (Nayar89)
double modifiedLaplacian(const cv::Mat& src)
{
    cv::Mat M = (Mat_<double>(3, 1) << -1, 2, -1);
    cv::Mat G = cv::getGaussianKernel(3, -1, CV_64F);
    
    cv::Mat Lx;
    cv::sepFilter2D(src, Lx, CV_64F, M, G);
    
    cv::Mat Ly;
    cv::sepFilter2D(src, Ly, CV_64F, G, M);
    
    cv::Mat FM = cv::abs(Lx) + cv::abs(Ly);
    
    double focusMeasure = cv::mean(FM).val[0];
    
    M.release();
    G.release();
    Lx.release();
    Ly.release();
    FM.release();
    
    return focusMeasure;
}

// OpenCV port of 'LAPV' algorithm (Pech2000)
double varianceOfLaplacian(const cv::Mat& src)
{
    cv::Mat lap;
    cv::Laplacian(src, lap, CV_64F);
    
    cv::Scalar mu, sigma;
    cv::meanStdDev(lap, mu, sigma);
    
    double focusMeasure = sigma.val[0]*sigma.val[0];
    
    lap.release();
    
    return focusMeasure;
}

// OpenCV port of 'TENG' algorithm (Krotkov86)
// NOTE: src is a single-channel Mat
double tenengrad(const cv::Mat& src, int ksize)
{
    cv::Mat Gx, Gy;
    cv::Sobel(src, Gx, CV_8U, 1, 0, ksize);
    cv::Sobel(src, Gy, CV_8U, 0, 1, ksize);
    
    cv::Mat FM = Gx.mul(Gx) + Gy.mul(Gy);
    
    double focusMeasure = cv::mean(FM).val[0];
    
    Gx.release();
    Gy.release();
    
    return focusMeasure;
}

// OpenCV port of 'GLVN' algorithm (Santos97)
double normalizedGraylevelVariance(const cv::Mat& src)
{
    cv::Scalar mu, sigma;
    cv::meanStdDev(src, mu, sigma);
    
    double focusMeasure = (sigma.val[0]*sigma.val[0]) / mu.val[0];
    
    return focusMeasure;
}

float getHistogramBinValue(Mat hist, int binNum)
{
    return hist.at<float>(binNum);
}
float getFrequencyOfBin(Mat channel)
{
    float frequency = 0.0;
    for( int i = 1; i < 255; i++ )
    {
        float Hc = abs(getHistogramBinValue(channel,i));
        frequency += Hc;
    }
    return frequency;
}
float computeShannonEntropy(Mat src)
{
    float entropy = 0.0;
    float frequency = getFrequencyOfBin(src);
    for( int i = 1; i < 255; i++ )
    {
        float Hc = abs(getHistogramBinValue(src,i));
        entropy += -(Hc/frequency) * log10((Hc/frequency));
    }
    std::cout << entropy << '\n';
    return entropy;
}

// Returns a vector of pixel values (0..255) for a grayscale image.
std::vector<int> pixelValues(Mat srcGray)
{
    int rows = srcGray.rows;
    int cols = srcGray.cols;
    std::vector<int> values;
    for (int r=0; r<rows; ++r) {
        for (int c=0; c<cols; ++c) {
            values.push_back(srcGray.at<uchar>(r, c));
        }
    }
    return values;
}

std::vector<int> filterByPercentile(std::vector<int>values, double minPercentile, double maxPercentile)
{
    std::vector<int> sliced;
    int vectorSize = (int)values.size();
    int indexStart = MAX(0, MIN(vectorSize-1, (int)round(minPercentile*vectorSize)));
    int indexEnd   = MAX(0, MIN(vectorSize-1, (int)round(maxPercentile*vectorSize)));
    for (int i=indexStart; i<=indexEnd; ++i) {
        sliced.push_back(values[i]);
    }
    return sliced;
}

std::vector<int> sortValues(std::vector<int>values, bool (*sortFn)(int a, int b))
{
    std::sort(values.begin(), values.end(), sortFn);
    return values;
}
bool sortFnAsc(int a,int b) { return (a<b); }
bool sortFnDesc(int a,int b) { return (a>b); }

double meanOfVector(std::vector<int> values) {
    double sum = std::accumulate(values.begin(), values.end(), 0.0);
    return sum / values.size();
}

double contrast(cv::Mat src) {
    std::vector<int> pixelVals = sortValues(pixelValues(src), sortFnAsc);
    double meanLow = meanOfVector(filterByPercentile(pixelVals, 0.25, 0.75));
    double meanHigh = meanOfVector(filterByPercentile(pixelVals, 0.995, 1.0));
    double contrast = meanHigh/MAX(1.0, meanLow);
    
    // std::vector<int> low = filterByPercentile(pixelVals, 0.25, 0.75);
    // std::vector<int> high = filterByPercentile(pixelVals, 0.99, 1.0);
    // NSLog(@"low: %d-%d  high: %d-%d", low.front(), low.back(), high.front(), high.back());
    // NSLog(@"Histogram:\n");
    // for (int i=0; i<=255; i++) {
    //     int numItems = (int)std::count_if(pixelVals.begin(), pixelVals.end(), [i](int j) { return j == i;});
    //     NSLog(@"%3.0f | %d\n", (float)i, numItems);
    // }

    return contrast;
}

double boundaryScore(cv::Mat src) {
    // Boundaries have decent-sized areas of very high brightness
    std::vector<int> pixelVals = sortValues(pixelValues(src), sortFnAsc);
    std::vector<int> highVals = filterByPercentile(pixelVals, 0.90, 1.0);
    return meanOfVector(highVals);
}

double contentScore(cv::Mat src) {
    // Content images have rather small bright dots
    return contrast(src);
}

double _mean(std::vector<int> v) {
    double sum = std::accumulate(v.begin(), v.end(), 0.0);
    return sum / v.size();
}

double _stdev(std::vector<int> v) {
    double mean = _mean(v);
    double sq_sum = std::inner_product(v.begin(), v.end(), v.begin(), 0.0);
    return std::sqrt(sq_sum / v.size() - mean * mean);
}

+ (ImageQuality) calculateFocusMetricFromIplImage:(IplImage *)iplImage
{
//    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//    NSData *data = [NSData dataWithBytes:iplImage->imageData length:iplImage->imageSize];
//    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
//    CGImageRef imageRef = CGImageCreate(
//                                        iplImage->width, iplImage->height,
//                                        iplImage->depth, iplImage->depth * iplImage->nChannels, iplImage->widthStep,
//                                        colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault,
//                                        provider, NULL, false, kCGRenderingIntentDefault
//                                        );
//    UIImage *uiImg = [UIImage imageWithCGImage:imageRef];
//    CGImageRelease(imageRef);
//    CGDataProviderRelease(provider);
//    CGColorSpaceRelease(colorSpace);
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"output-docs.png"];
//    [UIImagePNGRepresentation(uiImg) writeToFile:filePath atomically:YES];
    
    /*
    //generate a cv::mat from sampleBuffer
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
    int bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
    int bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);
    cv::Mat src = cv::Mat(bufferHeight,bufferWidth,CV_8UC4,pixel);
    CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
     */
    
    ImageQuality iq;

    // Derive a green/blue brightness representation (for contrast calculation)
    Mat src = Mat(iplImage);
    src.convertTo(src, CV_8UC3);
    Mat channels[4];
    split(src, channels);
    Mat green = channels[1];
    channels[0].release();
    channels[2].release();
    channels[3].release();
    
    /*
    Mat lap;
    //cv::Mat greenChannel;
    //cv::extractChannel(src, greenChannel, 1);
    
    Laplacian(src, lap, CV_64F);
*/

    // Calculate base metrics (used for contrast etc)
    //Scalar mean, stDev;
    //double minVal, maxVal;
    //meanStdDev(src, mean, stDev);
    //minMaxIdx(src, &minVal, &maxVal);

    iq.entropy = 0;  //computeShannonEntropy(src);
    iq.normalizedGraylevelVariance = 0;  // normalizedGraylevelVariance(src);
    iq.varianceOfLaplacian = 0;  // varianceOfLaplacian(src);
    iq.modifiedLaplacian = 0;  // modifiedLaplacian(src);
    iq.tenengrad1 = 0;  // tenengrad(src, 1);
    iq.tenengrad9 = 0;  // tenengrad(src, 9);
    iq.maxVal = 0;  // maxVal;
    iq.contrast = 0;

    // These are really processor intensive, so we only calculate one based
    // on whether we're in BF or FL.
    NSInteger currentFocusMode = [[TBScopeCamera sharedCamera] focusMode];
    if (currentFocusMode == TBScopeCameraFocusModeSharpness) {
        iq.tenengrad3 = tenengrad(green, 3);
        iq.greenContrast = 0;
    } else {
        iq.tenengrad3 = 0;
        iq.greenContrast = contrast(green);
    }
    iq.boundaryScore = boundaryScore(green);
    iq.contentScore = iq.greenContrast;  // contentScore(green);  (no sense in calculating it twice)
    iq.isBoundary = (iq.boundaryScore >= kMinBoundaryThreshold); //TODO: we should make this a multiplier over some baseline boundaryScore that is taken when the slide is centered (presumably that location is NOT a boundary)
    iq.isEmpty = (iq.contentScore < kMinContentThreshold);

    src.release();
    green.release();
    cvReleaseImage(&iplImage);
    
    return iq;
    
}


+ (UIImage *)cropImage:(UIImage*)image withBounds:(CGRect)rect {
    if (image.scale > 1.0f) {
        rect = CGRectMake(rect.origin.x * image.scale,
                          rect.origin.y * image.scale,
                          rect.size.width * image.scale,
                          rect.size.height * image.scale);
    }
    
    CGImageRef imageRef = CGImageCreateWithImageInRect(image.CGImage, rect);
    UIImage *result = [UIImage imageWithCGImage:imageRef scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(imageRef);
    return result;
}

@end
