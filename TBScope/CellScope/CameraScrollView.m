//
//  CameraScrollView.m
//  CellScope
//
//  Created by Frankie Myers on 11/7/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "CameraScrollView.h"
#import "TBScopeCamera.h"
#import "TBScopeFocusManager.h"
#import <GPUImage/GPUImage.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "TBScopeHardware.h"

@implementation CameraScrollView {
    GPUImageStillCamera *stillCamera;
    GPUImage3x3ConvolutionFilter *noopFilter;
    GPUImageColorMatrixFilter *colorFilter;
    GPUImageFilter *cropFilter;
    GPUImage3x3ConvolutionFilter *sobelX;
    GPUImage3x3ConvolutionFilter *sobelY;
    GPUImageAddBlendFilter *addFilter;
    GPUImageDifferenceBlendFilter *differenceFilter;
    GPUImageAlphaBlendFilter *alphaMaskFilterSharpness;
    GPUImageAlphaBlendFilter *alphaMaskFilterOutput;
    UIImage *maskImage;
    GPUImagePicture *maskImageSource;
    GPUImageLuminosity *averageLuminosity;
}

@synthesize previewLayerView;
@synthesize imageRotation;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self setBouncesZoom:NO];
        [self setBounces:NO];
        [self setScrollEnabled:YES];
        [self setMaximumZoomScale:10.0];
        
        [self setShowsHorizontalScrollIndicator:YES];
        [self setShowsVerticalScrollIndicator:YES];
        [self setIndicatorStyle:UIScrollViewIndicatorStyleWhite];
        
        //[[TBScopeCamera sharedCamera] setExposureLock:NO];
        //[[TBScopeCamera sharedCamera] setFocusLock:NO];
    }
    return self;
}

-(void)handleDoubleTapGesture:(UITapGestureRecognizer *)doubleTapGesture
{
    // Auto-focus
    // dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
    //     [[TBScopeFocusManager sharedFocusManager] clearLastGoodPositionAndMetric];
    //     [[TBScopeFocusManager sharedFocusManager] autoFocus];
    // });
    
    // Snap a z-stack
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    void (^__block snapZStack)(int, int, int) = ^(int startZPosition, int endZPosition, int increment) {
        if (startZPosition > endZPosition) return;

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            // Move to z position
            [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:startZPosition];
            
            // Pause for settling
            [NSThread sleepForTimeInterval:1.0f];
            
            // Snap a picture & save to assets library
            [stillCamera capturePhotoAsJPEGProcessedUpToFilter:noopFilter
                                         withCompletionHandler:^(NSData *data, NSError *error) {
                // UIImage *image = [cropFilter imageFromCurrentFramebuffer];
                // UIImage *image = [UIImage imageNamed:@"check.png"];
                // NSData *data = UIImageJPEGRepresentation(image, 1.0);
                [library writeImageDataToSavedPhotosAlbum:data
                                                 metadata:nil
                                          completionBlock:^(NSURL *url, NSError *error) {
                                              if (error) {
                                                  NSLog(@"Error saving picture, %@", error.description);
                                              } else {
                                                  NSLog(@"Saved picture at %d to %@", startZPosition, [url absoluteString]);
                                              }
                                              snapZStack(startZPosition + increment, endZPosition, increment);
                                          }];
            }];
        });
    };
    snapZStack(-40000, 10000, 500);
}

- (void)setUpPreview
{
    // Auto-focus on double-tap
    [self setUserInteractionEnabled:YES];
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                       action:@selector(handleDoubleTapGesture:)];
    doubleTapGesture.numberOfTapsRequired = 2;
    [self addGestureRecognizer:doubleTapGesture];

    [[TBScopeCamera sharedCamera] setUpCamera];

    // Setup image preview layer
    double captureWidth = 1920.0;
    double captureHeight = 1080.0;
    stillCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1920x1080
                                                      cameraPosition:AVCaptureDevicePositionBack];
    stillCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;

    // Set up filter whose output we'll use to capture stills
    noopFilter = [[GPUImage3x3ConvolutionFilter alloc] init];
    [noopFilter setConvolutionKernel:(GPUMatrix3x3){
        { 0.0f, 0.0f, 0.0f},
        { 0.0f, 1.0f, 0.0f},
        { 0.0f, 0.0f, 0.0f}
    }];
    [noopFilter forceProcessingAtSize:CGSizeMake(1920.0, 1080.0)];
    [stillCamera addTarget:noopFilter];

    // Discard all but green channel
    colorFilter = [[GPUImageColorMatrixFilter alloc] init];
    [colorFilter setColorMatrix:(GPUMatrix4x4){
        { 0.f, 0.f, 0.f, 0.f },
        { 0.f, 1.f, 0.f, 0.f },
        { 0.f, 0.f, 0.f, 0.f },
        { 0.f, 0.f, 0.f, 0.f },
    }];
    [stillCamera addTarget:colorFilter];

    // Crop the image to a square
    double cropFromSides = (captureWidth - captureHeight) / captureWidth / 2.0;
    double width = 1.0 - 2.0 * cropFromSides;
    CGRect cropRect = CGRectMake(cropFromSides, 0.0, width, 1.0);
    cropFilter = [[GPUImageCropFilter alloc] initWithCropRegion:cropRect];
    [colorFilter addTarget:cropFilter];

    // Add alpha mask to reduce to a circle (for output)
    maskImage = [UIImage imageNamed:@"circular_mask_1080x1080"];
    maskImageSource = [[GPUImagePicture alloc] initWithImage:maskImage smoothlyScaleOutput:YES];
    [maskImageSource processImage];
    alphaMaskFilterOutput = [[GPUImageAlphaBlendFilter alloc] init];
    alphaMaskFilterOutput.mix = 1.0f;
    [cropFilter addTarget:alphaMaskFilterOutput atTextureLocation:0];
    [maskImageSource addTarget:alphaMaskFilterOutput atTextureLocation:1];

    // Calculate sobelX
    sobelX = [[GPUImage3x3ConvolutionFilter alloc] init];
    [sobelX setConvolutionKernel:(GPUMatrix3x3){
        { -1.0f, 0.0f, 1.0f},
        { -2.0f, 0.0f, 2.0f},
        { -1.0f, 0.0f, 1.0f}
    }];
    [cropFilter addTarget:sobelX];

    // Calculate sobelY
    sobelY = [[GPUImage3x3ConvolutionFilter alloc] init];
    [sobelY setConvolutionKernel:(GPUMatrix3x3){
        {  1.0f,  2.0f,  1.0f},
        {  0.0f,  0.0f,  0.0f},
        { -1.0f, -2.0f, -1.0f}
    }];
    [cropFilter addTarget:sobelY];

    // Calculate tenegrad
    addFilter = [[GPUImageAddBlendFilter alloc] init];
    [sobelX addTarget:addFilter];
    [sobelY addTarget:addFilter];

    // Add difference blend filter
    differenceFilter = [[GPUImageDifferenceBlendFilter alloc] init];
    [cropFilter addTarget:differenceFilter atTextureLocation:0];
    [addFilter addTarget:differenceFilter atTextureLocation:1];

    // Add alpha mask to reduce to a circle (for sharpness)
    alphaMaskFilterSharpness = [[GPUImageAlphaBlendFilter alloc] init];
    alphaMaskFilterSharpness.mix = 1.0f;
    [differenceFilter addTarget:alphaMaskFilterSharpness atTextureLocation:0];
    [maskImageSource addTarget:alphaMaskFilterSharpness atTextureLocation:1];

    // Calculate fluorescence sharpness
    averageLuminosity = [[GPUImageLuminosity alloc] init];
    [averageLuminosity setLuminosityProcessingFinishedBlock:^(CGFloat luminosity, CMTime frameTime) {
        [[TBScopeCamera sharedCamera] setCurrentFocusMetric:luminosity];
    }];
    [alphaMaskFilterSharpness addTarget:averageLuminosity];

    // Show preview
    previewLayerView = [[GPUImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, 1920.0, 1080.0)];
    [alphaMaskFilterSharpness addTarget:previewLayerView];
    [stillCamera startCameraCapture];
    CGRect frame = CGRectMake(0, 0, captureWidth, captureHeight); //TODO: grab the resolution from the camera?
    [self addSubview:previewLayerView];
    [self setContentSize:frame.size];
    [self setDelegate:self];
    [self zoomExtents];
    [previewLayerView setNeedsDisplay];
    
    // If we're debugging, add a label to display image quality metrics
    self.imageQualityLabel = [[UILabel alloc] init];
    [self addSubview:self.imageQualityLabel];
    [self.imageQualityLabel setBounds:CGRectMake(0,0,800,800)];
    [self.imageQualityLabel setCenter:CGPointMake(550, 80)];
    self.imageQualityLabel.textColor = [UIColor whiteColor];
    self.imageQualityLabel.font = [UIFont fontWithName:@"Courier" size:14.0];
    [self bringSubviewToFront:self.imageQualityLabel];
    self.imageQualityLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.imageQualityLabel.numberOfLines = 0;
    self.imageQualityLabel.hidden = ![[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"];
    
//    //TODO: are these necessary?
//    [previewLayerView setNeedsDisplay];
//    [self setNeedsDisplay];

//    // Listen for ImageQuality updates
//    __weak CameraScrollView *weakSelf = self;
//    [[NSNotificationCenter defaultCenter] addObserverForName:@"ImageQualityReportReceived"
//              object:nil
//               queue:[NSOperationQueue mainQueue]
//          usingBlock:^(NSNotification *notification) {
//              NSValue *iqAsObject = notification.userInfo[@"ImageQuality"];
//              ImageQuality iq;
//              [iqAsObject getValue:&iq];
//              NSString *text = [NSString stringWithFormat:@"\n"
//                  "sharpness:  %@ (%3.3f)\n"
//                  "contrast:   %@ (%3.3f)\n"
//                  "boundryScr: %@ (%3.3f)\n"
//                  "isBoundary:  %@\n"
//                  "isEmpty:     %@\n\n",
//                  [@"" stringByPaddingToLength:(int)MIN(80, (iq.tenengrad3/14.375)) withString: @"|" startingAtIndex:0],
//                  iq.tenengrad3,
//                  [@"" stringByPaddingToLength:(int)MIN(80, (iq.greenContrast/0.0875)) withString: @"|" startingAtIndex:0],
//                  iq.greenContrast,
//                  [@"" stringByPaddingToLength:(int)MIN(80, (iq.boundaryScore/10.0)) withString: @"|" startingAtIndex:0],
//                  iq.boundaryScore,
//                  iq.isBoundary?@"YES":@"NO",
//                  iq.isEmpty?@"YES":@"NO"
//              ];
//              dispatch_async(dispatch_get_main_queue(), ^{
//                  // NSLog(@"Image quality report: %@", text);
//                  [weakSelf.imageQualityLabel setText:text];
//              });
//          }
//    ];
}

- (void)takeDownCamera
{
//    [self.previewLayerView removeFromSuperview];
//    [self.previewLayerView.layer removeFromSuperlayer];
//    self.previewLayerView = nil;
//    [[TBScopeCamera sharedCamera] takeDownCamera];
}



- (void) zoomExtents
{
    float horizZoom = self.bounds.size.width / previewLayerView.bounds.size.width;
    float vertZoom = self.bounds.size.height / previewLayerView.bounds.size.height;
    
    float zoomFactor = MIN(horizZoom,vertZoom);
    
    [self setMinimumZoomScale:zoomFactor];
    
    [self setZoomScale:zoomFactor animated:YES];
    
}

- (void) grabImage
{
//    [[TBScopeCamera sharedCamera] captureImage];  // TODO: add a completion block instead of processing it up the chain?

    //TODO: now update the field with the captured image and stop preview mode
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return previewLayerView;
}


@end
