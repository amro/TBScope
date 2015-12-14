//
//  CameraScrollView.m
//  CellScope
//
//  Created by Frankie Myers on 11/7/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "CameraScrollView.h"
#import "TBScopeCamera.h"
#import <GPUImage/GPUImage.h>

@implementation CameraScrollView {
    GPUImageVideoCamera *videoCamera;
    GPUImageFilter *cropFilter;
    GPUImage3x3ConvolutionFilter *convolutionFilter;
    GPUImageDifferenceBlendFilter *differenceFilter;
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

- (void)setUpPreview
{
    [[TBScopeCamera sharedCamera] setUpCamera];

    // Setup image preview layer
    videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1920x1080
                                                                           cameraPosition:AVCaptureDevicePositionBack];
    videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;

    // Crop the image
    CGRect cropRect = CGRectMake(0.118, 0.0, 0.764, 1.0);
    cropFilter = [[GPUImageCropFilter alloc] initWithCropRegion:cropRect];
    [videoCamera addTarget:cropFilter];

    // Add luminosity detection
    averageLuminosity = [[GPUImageLuminosity alloc] init];
    [averageLuminosity setLuminosityProcessingFinishedBlock:^(CGFloat luminosity, CMTime frameTime) {
        NSLog(@"Luminosity: %f", luminosity);
    }];
    [videoCamera addTarget:averageLuminosity];
    
    // Add convolution filter
    convolutionFilter = [[GPUImage3x3ConvolutionFilter alloc] init];
    [convolutionFilter setConvolutionKernel:(GPUMatrix3x3){
        {  0.0f,  -10.0f,   0.0f},
        {-10.0f,   41.0f, -10.0f},
        {  0.0f,  -10.0f,   0.0f}
    }];
    [cropFilter addTarget:convolutionFilter];

    // Add difference blend filter
    differenceFilter = [[GPUImageDifferenceBlendFilter alloc] init];
    [cropFilter addTarget:differenceFilter atTextureLocation:0];
    [convolutionFilter addTarget:differenceFilter atTextureLocation:1];

    previewLayerView = [[GPUImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, 1920.0, 1080.0)];
    [differenceFilter addTarget:previewLayerView];
    [videoCamera startCameraCapture];
    CGRect frame = CGRectMake(0, 0, 2592, 1936); //TODO: grab the resolution from the camera?
    [self addSubview:previewLayerView];
    [self setContentSize:frame.size];
    [self setDelegate:self];
    [self zoomExtents];
    [previewLayerView setNeedsDisplay];
    
//    // If we're debugging, add a label to display image quality metrics
//    self.imageQualityLabel = [[UILabel alloc] init];
//    [self addSubview:self.imageQualityLabel];
//    [self.imageQualityLabel setBounds:CGRectMake(0,0,500,500)];
//    [self.imageQualityLabel setCenter:CGPointMake(400, 80)];
//    self.imageQualityLabel.textColor = [UIColor whiteColor];
//    self.imageQualityLabel.font = [UIFont fontWithName:@"Courier" size:14.0];
//    [self bringSubviewToFront:self.imageQualityLabel];
//    self.imageQualityLabel.lineBreakMode = NSLineBreakByWordWrapping;
//    self.imageQualityLabel.numberOfLines = 0;
//    self.imageQualityLabel.hidden = ![[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"];
    
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
