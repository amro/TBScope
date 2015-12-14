//
//  TBScopeCamera.h
//  TBScope
//
//  Created by Jason Ardell on 9/24/15.
//  Copyright (c) 2015 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ImageQualityAnalyzer.h"

#define INFINITY_FOCUS_POSITION 1.0

typedef NS_ENUM(NSInteger, TBScopeCameraServiceAutofocus) {
    TBScopeCameraFocusModeSharpness,  // BF, based on tenegrad3 averaged over last 3 frames
    TBScopeCameraFocusModeContrast    // FL, based on contrast averaged over last 3 frames
};

@protocol TBScopeCameraDriver
@optional
@required
@property (nonatomic) ImageQuality currentImageQuality;
@property (nonatomic) float currentFocusMetric;
@property (nonatomic) BOOL isPreviewRunning;
@property (nonatomic) int focusMode;

-(void)setUpCamera;
-(void)setFocusLock:(BOOL)locked;
-(void)setExposureLock:(BOOL)locked;
-(void)setFocusPosition:(float)position;
-(void)setExposureDuration:(int)milliseconds
                  ISOSpeed:(int)isoSpeed;
-(void)setWhiteBalanceRed:(int)redGain
                    Green:(int)greenGain
                     Blue:(int)blueGain;
-(void)captureImage;
-(AVCaptureVideoPreviewLayer *)captureVideoPreviewLayer;
-(void)startPreview;
-(void)stopPreview;
-(void)takeDownCamera;
//-(UIView *)previewView;
@end

@interface TBScopeCamera : NSObject
+(id<TBScopeCameraDriver>)sharedCamera;
@end
