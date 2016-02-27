//
//  TBScopeFocusManagerTests.m
//  TBScope
//
//  Created by Jason Ardell on 10/2/15.
//  Copyright (c) 2015 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "TBScopeHardware.h"
#import "TBScopeHardwareMock.h"
#import "TBScopeFocusManager.h"
#import "TBScopeCamera.h"

@interface TBScopeFocusManagerTests : XCTestCase
@property (strong, nonatomic) TBScopeFocusManager *focusManager;
@end

@implementation TBScopeFocusManagerTests

- (void)setUp {
    [super setUp];

    // Swizzle [TBScopeHardware sharedHardware] to return TBScopeHardwareMock
    [self _toggleSharedHardwareSwizzling];

    // Reset hardware manager position to home
    [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZDown];

    // Set up focusManager
    self.focusManager = [TBScopeFocusManager sharedFocusManager];
    [self.focusManager clearLastGoodPositionAndMetric];
    [self _toggleFocusManagerPauseForSettlingSwizzling];
    [self _toggleFocusManagerThresholds];
}

- (void)tearDown {
    // Un-swizzle
    [self _toggleFocusManagerThresholds];
    [self _toggleFocusManagerPauseForSettlingSwizzling];
    [self _toggleSharedHardwareSwizzling];

    [super tearDown];
}

- (void)testThatItReturnsFailureCodeIfItHasNoLastGoodPositionAndBroadSweepFails {
    [self _toggleCurrentImageQualityMetricCurveFlat];
    TBScopeFocusManagerResult result = [self.focusManager autoFocus];
    [self _toggleCurrentImageQualityMetricCurveFlat];
    
    XCTAssertEqual(result, TBScopeFocusManagerResultFailure);
}

- (void)testThatItReturnsToStartingPositionIfItFailsToFocus {
    int startingZPosition = [[TBScopeHardware sharedHardware] zPosition];

    [self _toggleCurrentImageQualityMetricCurveFlat];
    [self.focusManager autoFocus];
    [self _toggleCurrentImageQualityMetricCurveFlat];

    int endingZPosition = [[TBScopeHardware sharedHardware] zPosition];
    XCTAssertEqual(endingZPosition, startingZPosition);
}

- (void)testThatItFailsWhenMaxFocusIsOutsideRange {
    [self _toggleCurrentImageQualityMetricCurvePeakOutsideRange];
    TBScopeFocusManagerResult result = [self.focusManager autoFocus];
    [self _toggleCurrentImageQualityMetricCurvePeakOutsideRange];

    XCTAssertEqual(result, TBScopeFocusManagerResultFailure);
}

- (void)testThatItRevertsToLastGoodPositionIfNothingGoodWasFound {
    [self _setLastGoodPositionAndMoveTo:60];
    
    [self _toggleCurrentImageQualityMetricCurveFlat];
    [self.focusManager autoFocus];
    [self _toggleCurrentImageQualityMetricCurveFlat];
    
    // Expect hardware zPosition to end where it started
    TBScopeHardwareMock *hardware = (TBScopeHardwareMock *)[TBScopeHardware sharedHardware];
    XCTAssertEqual(hardware.zPosition, 60);
}

- (void)testThatItCoarseFocusesWithoutLastGoodPosition {
    [self _toggleCurrentImageQualityMetricCurvePeakAt8000];
    [self.focusManager autoFocus];
    [self _toggleCurrentImageQualityMetricCurvePeakAt8000];

    // Expect hardware zPosition to end at 8000
    TBScopeHardwareMock *hardware = (TBScopeHardwareMock *)[TBScopeHardware sharedHardware];
    XCTAssertEqual(hardware.zPosition, 8000);
}

- (void)testThatItReturnsSuccessOnSuccessfulFocus {
    [self _toggleCurrentImageQualityMetricCurvePeakAt8000];
    TBScopeFocusManagerResult result = [self.focusManager autoFocus];
    [self _toggleCurrentImageQualityMetricCurvePeakAt8000];

    XCTAssertEqual(result, TBScopeFocusManagerResultSuccess);
}

- (void)testThatItUpdatesLastGoodPositionOnSuccess {
    self.focusManager.lastGoodPosition = -1;

    [self _toggleCurrentImageQualityMetricCurvePeakAt8000];
    [self.focusManager autoFocus];
    [self _toggleCurrentImageQualityMetricCurvePeakAt8000];

    XCTAssertEqual(self.focusManager.lastGoodPosition, 8000);
}

- (void)testThatItFindsTheOptimalFocusPositionNearToLastGoodPosition {
    [self _setLastGoodPositionAndMoveTo:8000];

    // Call focus
    [self _toggleCurrentImageQualityMetricCurvePeakAt8200];
    [self.focusManager autoFocus];
    [self _toggleCurrentImageQualityMetricCurvePeakAt8200];

    // Expect hardware zPosition to end at 8200
    TBScopeHardwareMock *hardware = (TBScopeHardwareMock *)[TBScopeHardware sharedHardware];
    XCTAssertEqual(hardware.zPosition, 8200);
}

- (void)testThatItFineFocusesWithoutLastGoodPosition {
    [self _toggleCurrentImageQualityMetricCurvePeakAt8200];
    [self.focusManager autoFocus];
    [self _toggleCurrentImageQualityMetricCurvePeakAt8200];

    // Expect hardware zPosition to end at 8200
    TBScopeHardwareMock *hardware = (TBScopeHardwareMock *)[TBScopeHardware sharedHardware];
    XCTAssertEqual(hardware.zPosition, 8200);
}

- (void)testThatItFineFocusesWithLastGoodPosition {
    self.focusManager.lastGoodPosition = 8100;
    [self _toggleCurrentImageQualityMetricCurvePeakAt8200];
    [self.focusManager autoFocus];
    [self _toggleCurrentImageQualityMetricCurvePeakAt8200];

    // Expect hardware zPosition to end at 8200
    TBScopeHardwareMock *hardware = (TBScopeHardwareMock *)[TBScopeHardware sharedHardware];
    XCTAssertEqual(hardware.zPosition, 8200);
}

#pragma private methods

// Make [TBScopeHardware sharedHardware] return TBScopeHardwareMock
- (void)_toggleSharedHardwareSwizzling
{
    Method originalMethod = class_getClassMethod([TBScopeHardware class], @selector(sharedHardware));
    Method swizzledMethod = class_getClassMethod([self class], @selector(_swizzledSharedHardware));
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

+ (id)_swizzledSharedHardware
{
    static id<TBScopeHardwareDriver> sharedHardware;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"Using swizzled sharedHardware method");
        sharedHardware = [[TBScopeHardwareMock alloc] init];
    });
    return sharedHardware;
}

- (void)_toggleFocusManagerThresholds
{
    Method originalMethod1 = class_getInstanceMethod([TBScopeFocusManager class], @selector(zPositionBroadSweepStepsPerSlice));
    Method swizzledMethod1 = class_getInstanceMethod([self class], @selector(_zPositionBroadSweepStepsPerSlice));
    method_exchangeImplementations(originalMethod1, swizzledMethod1);

    Method originalMethod2 = class_getInstanceMethod([TBScopeFocusManager class], @selector(zPositionBroadSweepMin));
    Method swizzledMethod2 = class_getInstanceMethod([self class], @selector(_zPositionBroadSweepMin));
    method_exchangeImplementations(originalMethod2, swizzledMethod2);

    Method originalMethod3 = class_getInstanceMethod([TBScopeFocusManager class], @selector(zPositionBroadSweepMax));
    Method swizzledMethod3 = class_getInstanceMethod([self class], @selector(_zPositionBroadSweepMax));
    method_exchangeImplementations(originalMethod3, swizzledMethod3);
}

- (int)_zPositionBroadSweepStepsPerSlice { return 500; }
- (int)_zPositionBroadSweepMin { return 0; }
- (int)_zPositionBroadSweepMax { return 10000; }

// Stub out [focusManager currentImageQualityMetric] to be a linear curve
// peaking at 8000 (for coarse focus testing).
//   metric = Math.max(0, Math.abs(8000 - zPosition));
//   ...
//   zPosition 7880 -> metric 0
//   zPosition 7900 -> metric 0
//   zPosition 7920 -> metric 20
//   zPosition 7940 -> metric 40
//   zPosition 7960 -> metric 60
//   zPosition 7980 -> metric 80
//   zPosition 8000 -> metric 100
//   zPosition 8020 -> metric 80
//   zPosition 8040 -> metric 60
//   zPosition 8060 -> metric 40
//   zPosition 8080 -> metric 20
//   zPosition 8100 -> metric 0
//   zPosition 8120 -> metric 0
//   zPosition 8140 -> metric 0
//   ...
- (void)_toggleCurrentImageQualityMetricCurvePeakAt8000
{
    Method originalMethod = class_getInstanceMethod([TBScopeFocusManager class], @selector(currentImageQualityMetric));
    Method swizzledMethod = class_getInstanceMethod([self class], @selector(_imageQualityCurvePeakAt8000));
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (float)_imageQualityCurvePeakAt8000
{
    TBScopeHardwareMock *hardware = (TBScopeHardwareMock *)[TBScopeHardware sharedHardware];
    float zPosition = [hardware zPosition];
    float imageQualityMetric = MAX(0.0, ABS(8000 - zPosition)*-1.0+100.0);
    NSLog(@"zPosition: %2f, metric: %2f", zPosition, imageQualityMetric);
    return imageQualityMetric;
}

// Stub out [focusManager currentImageQualityMetric] to be a linear curve
// peaking at 8200 (for fine focus testing)
//   metric = Math.max(0, Math.abs(8200 - zPosition));
//   ...
//   zPosition 7700 -> metric 500
//   zPosition 7800 -> metric 600
//   zPosition 7900 -> metric 700
//   zPosition 8000 -> metric 800
//   zPosition 8100 -> metric 900
//   zPosition 8200 -> metric 1000
//   zPosition 8300 -> metric 900
//   zPosition 8400 -> metric 800
//   zPosition 8500 -> metric 700
//   ...
- (void)_toggleCurrentImageQualityMetricCurvePeakAt8200
{
    Method originalMethod = class_getInstanceMethod([TBScopeFocusManager class], @selector(currentImageQualityMetric));
    Method swizzledMethod = class_getInstanceMethod([self class], @selector(_imageQualityCurvePeakAt8200));
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (float)_imageQualityCurvePeakAt8200
{
    TBScopeHardwareMock *hardware = (TBScopeHardwareMock *)[TBScopeHardware sharedHardware];
    float zPosition = [hardware zPosition];
    float imageQualityMetric = MAX(0.0, ABS(8200 - zPosition)*-1.0+1000.0);
    NSLog(@"zPosition: %2f, metric: %2f", zPosition, imageQualityMetric);
    return imageQualityMetric;
}

// Stub out [focusManager currentImageQualityMetric] to be flat
- (void)_toggleCurrentImageQualityMetricCurveFlat
{
    Method originalMethod = class_getInstanceMethod([TBScopeFocusManager class], @selector(currentImageQualityMetric));
    Method swizzledMethod = class_getInstanceMethod([self class], @selector(_imageQualityCurveFlat));
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (float)_imageQualityCurveFlat
{
    return 0.0;
}

// Stub out [focusManager currentImageQualityMetric] to be flat
- (void)_toggleCurrentImageQualityMetricCurvePeakOutsideRange
{
    Method originalMethod = class_getInstanceMethod([TBScopeFocusManager class], @selector(currentImageQualityMetric));
    Method swizzledMethod = class_getInstanceMethod([self class], @selector(_imageQualityCurveFlat));
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (float)_imageQualityCurvePeakOutsideRange
{
    TBScopeHardwareMock *hardware = (TBScopeHardwareMock *)[TBScopeHardware sharedHardware];
    float zPosition = [hardware zPosition];
    if (zPosition < [self.focusManager zPositionBroadSweepMin]) {
        return 0;
    } else if (zPosition > [self.focusManager zPositionBroadSweepMax]) {
        return 0;
    } else {
        int peak = [self.focusManager zPositionBroadSweepMax] + 5000;
        float imageQualityMetric = MAX(0.0, ABS(peak - zPosition)*-1.0+100.0);
        return imageQualityMetric;
    }
}

- (void)_toggleFocusManagerPauseForSettlingSwizzling
{
    Method originalMethod = class_getInstanceMethod([TBScopeFocusManager class], @selector(pauseForSettling));
    Method swizzledMethod = class_getInstanceMethod([self class], @selector(_pauseForSettling));
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

- (void)_pauseForSettling
{
    // Do nothing, it's really fast!
}

- (void)_setLastGoodPositionAndMoveTo:(int)zPosition
{
    [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:zPosition];
    self.focusManager.lastGoodPosition = zPosition;
}

@end
