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
    NSDecimalNumber *beads_500_01_001 = [self _focusMetricForImageAtPath:@"IMG_001.JPG"];
    NSDecimalNumber *beads_500_01_002 = [self _focusMetricForImageAtPath:@"IMG_002.JPG"];
    NSDecimalNumber *beads_500_01_003 = [self _focusMetricForImageAtPath:@"IMG_003.JPG"];
    NSDecimalNumber *beads_500_01_004 = [self _focusMetricForImageAtPath:@"IMG_004.JPG"];
    NSDecimalNumber *beads_500_01_005 = [self _focusMetricForImageAtPath:@"IMG_005.JPG"];
    NSDecimalNumber *beads_500_01_006 = [self _focusMetricForImageAtPath:@"IMG_006.JPG"];
    NSDecimalNumber *beads_500_01_007 = [self _focusMetricForImageAtPath:@"IMG_007.JPG"];
    NSDecimalNumber *beads_500_02_3041 = [self _focusMetricForImageAtPath:@"IMG_3041.JPG"];
    NSDecimalNumber *beads_500_02_3042 = [self _focusMetricForImageAtPath:@"IMG_3042.JPG"];
    NSDecimalNumber *beads_500_02_3043 = [self _focusMetricForImageAtPath:@"IMG_3043.JPG"];
    NSDecimalNumber *beads_500_02_3044 = [self _focusMetricForImageAtPath:@"IMG_3044.JPG"];
    NSDecimalNumber *beads_500_02_3045 = [self _focusMetricForImageAtPath:@"IMG_3045.JPG"];
    NSDecimalNumber *beads_500_02_3046 = [self _focusMetricForImageAtPath:@"IMG_3046.JPG"];
    NSDecimalNumber *beads_500_02_3047 = [self _focusMetricForImageAtPath:@"IMG_3047.JPG"];
    NSDecimalNumber *beads_500_02_3048 = [self _focusMetricForImageAtPath:@"IMG_3048.JPG"];
    NSDecimalNumber *beads_500_02_3049 = [self _focusMetricForImageAtPath:@"IMG_3049.JPG"];
    NSDecimalNumber *beads_500_03_3427 = [self _focusMetricForImageAtPath:@"IMG_3427.JPG"];
    NSDecimalNumber *beads_500_03_3428 = [self _focusMetricForImageAtPath:@"IMG_3428.JPG"];
    NSDecimalNumber *beads_500_03_3429 = [self _focusMetricForImageAtPath:@"IMG_3429.JPG"];
    NSDecimalNumber *beads_500_03_3430 = [self _focusMetricForImageAtPath:@"IMG_3430.JPG"];
    NSDecimalNumber *beads_500_03_3431 = [self _focusMetricForImageAtPath:@"IMG_3431.JPG"];
    NSDecimalNumber *beads_500_03_3432 = [self _focusMetricForImageAtPath:@"IMG_3432.JPG"];
    NSDecimalNumber *beads_500_03_3433 = [self _focusMetricForImageAtPath:@"IMG_3433.JPG"];
    NSDecimalNumber *beads_500_03_3434 = [self _focusMetricForImageAtPath:@"IMG_3434.JPG"];
    NSDecimalNumber *beads_500_03_3435 = [self _focusMetricForImageAtPath:@"IMG_3435.JPG"];
    NSDecimalNumber *beads_500_03_3436 = [self _focusMetricForImageAtPath:@"IMG_3436.JPG"];
    NSDecimalNumber *beads_500_03_3437 = [self _focusMetricForImageAtPath:@"IMG_3437.JPG"];
    NSDecimalNumber *beads_500_03_3438 = [self _focusMetricForImageAtPath:@"IMG_3438.JPG"];
    NSDecimalNumber *beads_500_03_3439 = [self _focusMetricForImageAtPath:@"IMG_3439.JPG"];
    NSDecimalNumber *beads_500_03_3440 = [self _focusMetricForImageAtPath:@"IMG_3440.JPG"];
    NSDecimalNumber *beads_500_03_3441 = [self _focusMetricForImageAtPath:@"IMG_3441.JPG"];
    NSDecimalNumber *beads_500_03_3442 = [self _focusMetricForImageAtPath:@"IMG_3442.JPG"];
    NSDecimalNumber *beads_500_03_3443 = [self _focusMetricForImageAtPath:@"IMG_3443.JPG"];
    NSDecimalNumber *beads_500_03_3444 = [self _focusMetricForImageAtPath:@"IMG_3444.JPG"];
    NSDecimalNumber *beads_500_03_3445 = [self _focusMetricForImageAtPath:@"IMG_3445.JPG"];
    NSDecimalNumber *beads_500_03_3446 = [self _focusMetricForImageAtPath:@"IMG_3446.JPG"];
    NSDecimalNumber *beads_500_03_3447 = [self _focusMetricForImageAtPath:@"IMG_3447.JPG"];
    NSDecimalNumber *beads_500_03_3448 = [self _focusMetricForImageAtPath:@"IMG_3448.JPG"];
    NSDecimalNumber *beads_500_03_3449 = [self _focusMetricForImageAtPath:@"IMG_3449.JPG"];
    NSDecimalNumber *beads_500_03_3450 = [self _focusMetricForImageAtPath:@"IMG_3450.JPG"];
    NSDecimalNumber *beads_500_03_3451 = [self _focusMetricForImageAtPath:@"IMG_3451.JPG"];
    NSDecimalNumber *beads_500_03_3452 = [self _focusMetricForImageAtPath:@"IMG_3452.JPG"];

    NSArray *testCases = @[
        // Blurrier image       Sharper image
        @[ beads_500_01_001,    beads_500_01_002    ],
        @[ beads_500_01_002,    beads_500_01_003    ],
        @[ beads_500_01_003,    beads_500_01_004    ],
        @[ beads_500_01_004,    beads_500_01_005    ],
        @[ beads_500_01_005,    beads_500_01_006    ],
        @[ beads_500_01_006,    beads_500_01_007    ],
        @[ beads_500_02_3041,   beads_500_02_3042   ],
        @[ beads_500_02_3042,   beads_500_02_3043   ],
        @[ beads_500_02_3043,   beads_500_02_3044   ],
        @[ beads_500_02_3044,   beads_500_02_3045   ],
        @[ beads_500_02_3045,   beads_500_02_3046   ],
        @[ beads_500_02_3046,   beads_500_02_3047   ],
        @[ beads_500_02_3047,   beads_500_02_3048   ],
        @[ beads_500_02_3048,   beads_500_02_3049   ],
        @[ beads_500_03_3427,   beads_500_03_3428   ],
        @[ beads_500_03_3428,   beads_500_03_3429   ],
        @[ beads_500_03_3429,   beads_500_03_3430   ],
        @[ beads_500_03_3430,   beads_500_03_3431   ],
        @[ beads_500_03_3431,   beads_500_03_3432   ],
        @[ beads_500_03_3432,   beads_500_03_3433   ],
        @[ beads_500_03_3433,   beads_500_03_3434   ],
        @[ beads_500_03_3434,   beads_500_03_3435   ],
        @[ beads_500_03_3435,   beads_500_03_3436   ],
        @[ beads_500_03_3436,   beads_500_03_3437   ],
        @[ beads_500_03_3437,   beads_500_03_3438   ],
        @[ beads_500_03_3438,   beads_500_03_3439   ],
        @[ beads_500_03_3439,   beads_500_03_3440   ],
        @[ beads_500_03_3440,   beads_500_03_3441   ],
        @[ beads_500_03_3441,   beads_500_03_3442   ],
        @[ beads_500_03_3442,   beads_500_03_3443   ],
        @[ beads_500_03_3443,   beads_500_03_3444   ],
        @[ beads_500_03_3444,   beads_500_03_3445   ],
        @[ beads_500_03_3445,   beads_500_03_3446   ],
        @[ beads_500_03_3446,   beads_500_03_3447   ],
        @[ beads_500_03_3447,   beads_500_03_3448   ],
        @[ beads_500_03_3448,   beads_500_03_3449   ],
        @[ beads_500_03_3449,   beads_500_03_3450   ],
        @[ beads_500_03_3450,   beads_500_03_3451   ],
        @[ beads_500_03_3451,   beads_500_03_3452   ],
    ];
    for (NSArray *testCase in testCases) {
        NSDecimalNumber *blurrierContrast = testCase[0];
        NSDecimalNumber *sharperContrast  = testCase[1];
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

- (NSDecimalNumber *)_focusMetricForImageAtPath:(NSString *)imagePath {
    // Load the image
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] resourcePath];
    NSString *filePath = [bundlePath stringByAppendingPathComponent:imagePath];
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

    // Crop out a circle
    UIImage *maskImage = [UIImage imageNamed:@"circular_mask_1080x1080"];
    GPUImagePicture *maskImageSource = [[GPUImagePicture alloc] initWithImage:maskImage smoothlyScaleOutput:YES];
    [maskImageSource processImage];
    GPUImageAlphaBlendFilter *alphaMaskFilter = [[GPUImageAlphaBlendFilter alloc] init];
    alphaMaskFilter.mix = 1.0f;
    [cropFilter addTarget:alphaMaskFilter atTextureLocation:0];
    [maskImageSource addTarget:alphaMaskFilter atTextureLocation:1];

    // Generate sharpened image
    GPUImageSharpenFilter *sharpenFilter = [[GPUImageSharpenFilter alloc] init];
    [sharpenFilter setSharpness:1.0];
    [alphaMaskFilter addTarget:sharpenFilter];

    // Calculate tenegrad
    GPUImageDifferenceBlendFilter *differenceFilter = [[GPUImageDifferenceBlendFilter alloc] init];
    [sharpenFilter addTarget:differenceFilter];
    [alphaMaskFilter addTarget:differenceFilter];

    // Increase exposure to brighten the bright pixels more than the dark pixels
    GPUImageExposureFilter *exposureFilter = [[GPUImageExposureFilter alloc] init];
    exposureFilter.exposure = 3.75;
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

    NSLog(@"Image %@ has focus metric %3.6f", imagePath, focusMetric);
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
