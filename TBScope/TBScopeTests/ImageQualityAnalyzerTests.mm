//
//  ImageQualityAnalyzerTests.m
//  TBScope
//
//  Created by Jason Ardell on 10/1/15.
//  Copyright (c) 2015 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "TBScopeCamera.h"
#import "ImageQualityAnalyzer.h"
#import <GPUImage/GPUImage.h>
#import <PromiseKit/Promise.h>
#import <PromiseKit/Promise+Hang.h>

@interface ImageQualityAnalyzerTests : XCTestCase
@end

@implementation ImageQualityAnalyzerTests

static int const kLastBoundaryImageIndex = 10;
static int const kLastContentImageIndex = 8;
static int const kLastEmptyImageIndex = 11;

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testThatFocusedBrightfieldImageIsSharperThanBlurryBrightfield {
    [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeSharpness];

    ImageQuality focusedIQ = [self _imageQualityForImageNamed:@"bf_focused"];
    ImageQuality blurryIQ = [self _imageQualityForImageNamed:@"bf_blurry"];

    // Expect bf_focused_sharpness > bf_blurry_sharpness
    XCTAssert(focusedIQ.tenengrad3 > blurryIQ.tenengrad3);
}

- (void)testThatFocusedFluorescenceImagesHaveHigherContrastThanBlurryFluorescence {
    // Calculate focus metrics
    NSDecimalNumber *focus_01 = [self _focusMetricForImageNamed:@"focus_01"];
    NSDecimalNumber *focus_02 = [self _focusMetricForImageNamed:@"focus_02"];
    NSDecimalNumber *focus_03 = [self _focusMetricForImageNamed:@"focus_03"];
    NSDecimalNumber *focus_04 = [self _focusMetricForImageNamed:@"focus_04"];
    NSDecimalNumber *focus_05 = [self _focusMetricForImageNamed:@"focus_05"];
    NSDecimalNumber *focus_06 = [self _focusMetricForImageNamed:@"focus_06"];
    NSDecimalNumber *focus_07 = [self _focusMetricForImageNamed:@"focus_07"];

    NSArray *testCases = @[
        // Sharper image        Blurrier image
        @[ focus_07,            focus_06        ],
        @[ focus_06,            focus_05        ],
        @[ focus_05,            focus_04        ],
        @[ focus_04,            focus_03        ],
        @[ focus_03,            focus_02        ],
        @[ focus_02,            focus_01        ],
    ];
    for (NSArray *testCase in testCases) {
        NSDecimalNumber *sharperContrast = testCase[0];
        NSDecimalNumber *blurrierContrast = testCase[1];
        XCTAssertGreaterThan([sharperContrast doubleValue], [blurrierContrast doubleValue]);
    }
}

- (void)testThatBoundaryDetectionWorks {
    NSMutableArray *testCases = [[NSMutableArray alloc] init];

    // Calculate content scores for all images
    NSDictionary *scores = @{
                             @"boundary" : [[NSMutableDictionary alloc] init],
                             @"content"  : [[NSMutableDictionary alloc] init],
                             @"empty"    : [[NSMutableDictionary alloc] init],
                             };
    for (int i=1; i<=kLastBoundaryImageIndex; i++) {
        NSString *imageName = [NSString stringWithFormat:@"fl_boundary_%02d", i];
        NSDecimalNumber *score = [self _boundaryScoreForImageNamed:imageName];
        [scores[@"boundary"] setObject:score forKey:[NSNumber numberWithInt:i]];
    }
    for (int i=1; i<=kLastContentImageIndex; i++) {
        NSString *imageName = [NSString stringWithFormat:@"fl_content_%02d", i];
        NSDecimalNumber *score = [self _boundaryScoreForImageNamed:imageName];
        [scores[@"content"] setObject:score forKey:[NSNumber numberWithInt:i]];
    }
    for (int i=1; i<=kLastEmptyImageIndex; i++) {
        NSString *imageName = [NSString stringWithFormat:@"fl_empty_%02d", i];
        NSDecimalNumber *score = [self _boundaryScoreForImageNamed:imageName];
        [scores[@"empty"] setObject:score forKey:[NSNumber numberWithInt:i]];
    }

    for (int boundaryIndex=1; boundaryIndex<=kLastBoundaryImageIndex; boundaryIndex++) {
        // Boundary images have higher boundary score than content images
        for (int contentIndex=1; contentIndex<=kLastContentImageIndex; contentIndex++) {
            NSArray *testCase = @[
                                  scores[@"boundary"][[NSNumber numberWithInt:boundaryIndex]],
                                  scores[@"content"][[NSNumber numberWithInt:contentIndex]],
                                  ];
            [testCases addObject:testCase];
        }

        // Boundary images have higher boundary score than empty images
        for (int emptyIndex=1; emptyIndex<=kLastEmptyImageIndex; emptyIndex++) {
            NSArray *testCase = @[
                                  scores[@"boundary"][[NSNumber numberWithInt:boundaryIndex]],
                                  scores[@"empty"][[NSNumber numberWithInt:emptyIndex]],
                                  ];
            [testCases addObject:testCase];
        }
    }

    for (NSArray *testCase in testCases) {
        NSDecimalNumber *higherContentScore = testCase[0];
        NSDecimalNumber *lowerContentScore = testCase[1];
        XCTAssertGreaterThan([higherContentScore doubleValue], [lowerContentScore doubleValue]);
    }
}

- (void)testThatContentDetectionWorks {
    NSMutableArray *testCases = [[NSMutableArray alloc] init];

    // Set focus mode to FL so ImageQuality calculates contrast
    int focusMode = TBScopeCameraFocusModeContrast;
    [[TBScopeCamera sharedCamera] setFocusMode:focusMode];

    // Calculate content scores for all images
    NSDictionary *scores = @{
                             @"content"  : [[NSMutableDictionary alloc] init],
                             @"empty"    : [[NSMutableDictionary alloc] init],
                             };
    for (int i=1; i<=kLastContentImageIndex; i++) {
        NSString *imageName = [NSString stringWithFormat:@"fl_content_%02d", i];
        NSDecimalNumber *score = [self _contentScoreForImageNamed:imageName];
        [scores[@"content"] setObject:score forKey:[NSNumber numberWithInt:i]];
    }
    for (int i=1; i<=kLastEmptyImageIndex; i++) {
        NSString *imageName = [NSString stringWithFormat:@"fl_empty_%02d", i];
        NSDecimalNumber *score = [self _contentScoreForImageNamed:imageName];
        [scores[@"empty"] setObject:score forKey:[NSNumber numberWithInt:i]];
    }

    for (int contentIndex=1; contentIndex<=kLastContentImageIndex; contentIndex++) {
        // Content images have higher content score than empty images
        for (int emptyIndex=1; emptyIndex<=kLastEmptyImageIndex; emptyIndex++) {
            NSArray *testCase = @[
                                  scores[@"content"][[NSNumber numberWithInt:contentIndex]],
                                  scores[@"empty"][[NSNumber numberWithInt:emptyIndex]],
                                  ];
            [testCases addObject:testCase];
        }
    }

    for (NSArray *testCase in testCases) {
        NSDecimalNumber *higherContentScore = testCase[0];
        NSDecimalNumber *lowerContentScore = testCase[1];
        XCTAssertGreaterThan([higherContentScore doubleValue], [lowerContentScore doubleValue]);
    }
}

#pragma helper methods

- (NSDecimalNumber *)_focusMetricForImageNamed:(NSString *)imageName {
    // Load the image
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
    UIImage *image = [UIImage imageWithContentsOfFile:filePath];

    // Convert image to GPU input
    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithImage:image];

    // Discard all but green channel
    GPUImageColorMatrixFilter *colorFilter = [[GPUImageColorMatrixFilter alloc] init];
    [colorFilter setColorMatrix:(GPUMatrix4x4){
        { 0.f, 0.f, 0.f, 0.f },
        { 0.f, 1.f, 0.f, 0.f },
        { 0.f, 0.f, 0.f, 0.f },
        { 0.f, 0.f, 0.f, 1.f },
    }];
    [stillImageSource addTarget:colorFilter];

    // Crop the image to a square
    double captureWidth = 1920.0;
    double captureHeight = 1080.0;
    double targetWidth = 1080;
    double targetHeight = 1080;
    double cropFromLeft = (captureWidth - targetWidth) / captureWidth / 2.0;
    double cropFromTop = (captureHeight - targetHeight) / captureHeight / 2.0;
    double width = 1.0 - 2.0 * cropFromLeft;
    double height = 1.0 - 2.0 * cropFromTop;
    CGRect cropRect = CGRectMake(cropFromLeft, cropFromTop, width, height);
    GPUImageCropFilter *cropFilter = [[GPUImageCropFilter alloc] initWithCropRegion:cropRect];
    [colorFilter addTarget:cropFilter];

    // Generate sharpened image
    GPUImageSharpenFilter *sharpenFilter = [[GPUImageSharpenFilter alloc] init];
    [sharpenFilter setSharpness:1.0];
    [cropFilter addTarget:sharpenFilter];

    // Calculate tenegrad
    GPUImageDifferenceBlendFilter *differenceFilter = [[GPUImageDifferenceBlendFilter alloc] init];
    [sharpenFilter addTarget:differenceFilter];
    [cropFilter addTarget:differenceFilter];

    // Maybe try to run either a brighten filter or a contrast filter,
    // then checking the average green value, since the values are so
    // low that there's not much contrast.
    GPUImageExposureFilter *exposureFilter = [[GPUImageExposureFilter alloc] init];
    exposureFilter.exposure = 3.5;
    [differenceFilter addTarget:exposureFilter];

    // Get the metric
    GPUImageAverageColor *averageColorFilter = [[GPUImageAverageColor alloc] init];
    __block double focusMetric;
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        [averageColorFilter setColorAverageProcessingFinishedBlock:^(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha, CMTime frameTime) {
            focusMetric = green;
            resolve(nil);
        }];
    }];
    [exposureFilter useNextFrameForImageCapture];
    [exposureFilter addTarget:averageColorFilter];

    // Wait for metric
    [stillImageSource processImage];
    [PMKPromise hang:promise];

    NSLog(@"Image %@ has focus metric %3.6f", imageName, focusMetric);
    return [[NSDecimalNumber alloc] initWithDouble:focusMetric];
}

- (NSDecimalNumber *)_boundaryScoreForImageNamed:(NSString *)imageName {
    ImageQuality imageQuality =[self _imageQualityForImageNamed:imageName];
    double boundaryScore = imageQuality.boundaryScore;
    NSLog(@"Image %@ has boundaryScore %3.3f", imageName, boundaryScore);
    return [[NSDecimalNumber alloc] initWithDouble:boundaryScore];
}

- (NSDecimalNumber *)_contentScoreForImageNamed:(NSString *)imageName {
    ImageQuality imageQuality =[self _imageQualityForImageNamed:imageName];
    double boundaryScore = imageQuality.contentScore;
    NSLog(@"Image %@ has contentScore %3.3f", imageName, boundaryScore);
    return [[NSDecimalNumber alloc] initWithDouble:boundaryScore];
}

- (ImageQuality)_imageQualityForImageNamed:(NSString *)imageName {
    // Load up UIImage
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
    UIImage *uiImage = [UIImage imageWithContentsOfFile:filePath];

    // Convert UIImage to an IplImage
    IplImage *iplImage = [[self class] createIplImageFromUIImage:uiImage];
    ImageQuality iq = [ImageQualityAnalyzer calculateFocusMetricFromIplImage:iplImage];

    // Release an nullify iplImage
    // cvReleaseImage(&iplImage);  // not sure why this crashes
    iplImage = NULL;

    return iq;
}

+ (IplImage *)createIplImageFromUIImage:(UIImage *)image {
    // Getting CGImage from UIImage
    CGImageRef imageRef = image.CGImage;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // Creating temporal IplImage for drawing
    IplImage *iplImage = cvCreateImage(
                                       cvSize(image.size.width,image.size.height), IPL_DEPTH_8U, 4
                                       );
    // Creating CGContext for temporal IplImage
    CGContextRef contextRef = CGBitmapContextCreate(
                                                    iplImage->imageData, iplImage->width, iplImage->height,
                                                    iplImage->depth, iplImage->widthStep,
                                                    colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault
                                                    );
    // Drawing CGImage to CGContext
    CGContextDrawImage(
                       contextRef,
                       CGRectMake(0, 0, image.size.width, image.size.height),
                       imageRef
                       );
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    // Creating result IplImage
    IplImage *converted = cvCreateImage(cvGetSize(iplImage), IPL_DEPTH_8U, 3);
    cvCvtColor(iplImage, converted, CV_RGBA2BGR);
    cvReleaseImage(&iplImage);

    // Crop IplImage
    int cropDim = CROP_WINDOW_SIZE;
    IplImage *cropped = 0;
    cvSetImageROI(converted, cvRect(converted->width/2-(cropDim/2), converted->height/2-(cropDim/2), cropDim, cropDim));
    cropped = cvCreateImage(cvGetSize(converted),
                            converted->depth,
                            converted->nChannels);
    cvCopy(converted, cropped, NULL);
    cvReleaseImage(&converted);
    
    return cropped;
}

@end
