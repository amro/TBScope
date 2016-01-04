//
//  TBScopeFocusManager.m
//  TBScope
//
//  Created by Jason Ardell on 10/2/15.
//  Copyright (c) 2015 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "TBScopeFocusManager.h"
#import "TBScopeCamera.h"
#import "TBScopeHardware.h"
#import "TBScopeData.h"

@interface TBScopeFocusManager ()
@property (nonatomic) int currentIterationBestPosition;
@property (nonatomic) float currentIterationBestMetric;
@end

@implementation TBScopeFocusManager

@synthesize lastGoodPosition;

+ (id)sharedFocusManager
{
    static TBScopeFocusManager *sharedFocusManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedFocusManager = [[TBScopeFocusManager alloc] initPrivate];
    });
    return sharedFocusManager;
}

- (instancetype)init
{
    [NSException raise:@"Singleton" format:@"Use +[TBScopeFocusManager sharedFocusManager]"];
    return nil;
}

- (instancetype)initPrivate
{
    if (self = [super init]) {
        // Do additional setup here
        [self clearLastGoodPositionAndMetric];
    }
    return self;
}

- (int)zPositionBroadSweepStepsPerSlice
{
    return 100;
    return (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FocusBroadSweepStepSize"];  // steps
}

- (int)zPositionBroadSweepMax
{
    return 20000;
    return (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultFocusZ"] +
            ((int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FocusBroadSweepRange"] / 2) ;
    
}

- (int)zPositionBroadSweepMin
{
    return -40000;
    return (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultFocusZ"] -
    ((int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FocusBroadSweepRange"] / 2) ;
}

- (float)currentImageQualityMetric
{
    return [[TBScopeCamera sharedCamera] currentFocusMetric];
}

- (void)clearLastGoodPositionAndMetric
{
    self.lastGoodPosition = -1;
    self.lastGoodMetric = 0.0;
}

- (TBScopeFocusManagerResult)autoFocus
{
    // Set up
    [self _resetCurrentIterationStats];
    int startingZPosition = [[TBScopeHardware sharedHardware] zPosition];

    // If we have a lastGoodPosition
    if (self.lastGoodPosition != -1) {
        // TODO: we should probably make this a wider hill climb because it's
        // possible we're off by a good margin here
        if ([self _fineFocus] == TBScopeFocusManagerResultSuccess) {
            [self _updateLastGoodPositionAndMetric];
            [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:self.currentIterationBestPosition];
            [[TBScopeHardware sharedHardware] waitForStage];
            return TBScopeFocusManagerResultSuccess;
        }
    }

    // Otherwise start from a very coarse focus and work our way finer
    if ([self _coarseFocus] == TBScopeFocusManagerResultSuccess) {
        // [self _fineFocus];
        [self _updateLastGoodPositionAndMetric];
        [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:self.currentIterationBestPosition];
        [[TBScopeHardware sharedHardware] waitForStage];
        [TBScopeData CSLog:[NSString stringWithFormat:@"Auto focus successful, best metric = %f, best position = %d",self.currentIterationBestMetric,self.currentIterationBestPosition] inCategory:@"CAPTURE"];
        return TBScopeFocusManagerResultSuccess;
    } else if (self.lastGoodPosition!=-1) {
        [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:self.lastGoodPosition];
        [[TBScopeHardware sharedHardware] waitForStage];
        [TBScopeData CSLog:@"Auto focus failed, returning to last good position." inCategory:@"CAPTURE"];
        return TBScopeFocusManagerResultReturn;
    }

    // Utter failure to focus, return to starting position
    [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:startingZPosition];
    [[TBScopeHardware sharedHardware] waitForStage];
    [TBScopeData CSLog:@"Auto focus failure" inCategory:@"CAPTURE"];
    return TBScopeFocusManagerResultFailure;
}

- (TBScopeFocusManagerResult)_coarseFocus
{
    [TBScopeData CSLog:@"Starting coarse focus" inCategory:@"CAPTURE"];

    // Start at zPositionBroadSweepMin
    [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:[self zPositionBroadSweepMin]];
    [[TBScopeHardware sharedHardware] waitForStage];

    NSLog(@"min %d",[self zPositionBroadSweepMin]);
    NSLog(@"max %d",[self zPositionBroadSweepMax]);
    NSLog(@"step %d",[self zPositionBroadSweepStepsPerSlice]);

    return [self _sweepInStepIncrement:[self zPositionBroadSweepStepsPerSlice]
                       fromMinPosition:[self zPositionBroadSweepMin]
                         toMaxPosition:[self zPositionBroadSweepMax]];
}

- (TBScopeFocusManagerResult)_sweepInStepIncrement:(int)stepsPerSlice
                                   fromMinPosition:(int)minPosition
                                     toMaxPosition:(int)maxPosition
{
    // Do a full sweep from min to max, gathering samples
    int position;
    NSMutableArray *samples = [[NSMutableArray alloc] init];
    for (position=minPosition; position<=maxPosition; position+=stepsPerSlice) {
        // Move into new position
        [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:position];
        [[TBScopeHardware sharedHardware] waitForStage];
        [self pauseForSettling];

        // Gather metric
        float metric = [self currentImageQualityMetric];
        [samples addObject:[NSNumber numberWithFloat:metric]];
        NSLog(@"Sharpness at %d is %3.6f", position, metric);
    }

    // Scan back from max to min and stop at the first metric that is
    // >N stdevs above mean
    float mean = [self _mean:samples];
    float stdev = [self _stdev:samples];
    float targetFocus = mean+FOCUS_SUCCESS_STDDEV_MULTIPLIER*stdev;
    NSLog(@"Mean: %3.6f, Stdev: %3.6f, Target: %3.6f", mean, stdev, targetFocus);
    while (position >= minPosition) {
        // Move into new position
        position -= stepsPerSlice;
        [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:position];
        [[TBScopeHardware sharedHardware] waitForStage];
        [self pauseForSettling];

        // Gather metric
        float metric = [self currentImageQualityMetric];
        NSLog(@"Sharpness at %d is %3.6f", position, metric);
        if (metric > targetFocus) {
            NSLog(@"Setting %d as focused position", position);
            [self _recordNewCurrentIterationPosition:position Metric:metric];
            return TBScopeFocusManagerResultSuccess;
        }
    }

    return TBScopeFocusManagerResultFailure;
}

- (TBScopeFocusManagerResult)_fineFocus
{
    [TBScopeData CSLog:@"Starting fine focus" inCategory:@"CAPTURE"];
    
    // Calculate min and max positions
    int currentPosition = [[TBScopeHardware sharedHardware] zPosition];
    int minPosition = currentPosition - 1000;
    int maxPosition = currentPosition + 1000;

    // Fine sweep
    return [self _sweepInStepIncrement:20
                       fromMinPosition:minPosition
                         toMaxPosition:maxPosition];
}

- (TBScopeFocusManagerResult)_hillClimbInSlicesOf:(int)stepsPerSlice
                               slicesPerIteration:(int)slicesPerIteration
                                      inDirection:(int)direction  // -1 is down, 0 is not sure, 1 is up
                                  withMinPosition:(int)minPosition
                                      maxPosition:(int)maxPosition
{
    [TBScopeData CSLog:[NSString stringWithFormat:@"Hill Climbing from z: %d to %d and direction: %d",minPosition,maxPosition,direction] inCategory:@"CAPTURE"];
    
    // If we're outside min/max position, return failure
    int startZPosition = [[TBScopeHardware sharedHardware] zPosition];
    if (startZPosition < minPosition || startZPosition+stepsPerSlice*slicesPerIteration > maxPosition) {
        return TBScopeFocusManagerResultFailure;
    }
    
    // Gather slicesPerIteration successive points starting at start point
    NSInteger bestPositionSoFar = nil;
    float bestMetricSoFar = -1.0;
    NSMutableArray *samples = [NSMutableArray arrayWithArray:@[]];
    for (int i=0; i<slicesPerIteration; ++i) {
        // Move to position
        int targetZPosition = startZPosition + i*stepsPerSlice;
        [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:targetZPosition];
        [[TBScopeHardware sharedHardware] waitForStage];
        [self pauseForSettling];  // does this help reduce blurring?

        // Gather metric
        float metric = [self currentImageQualityMetric];
        NSLog(@"Sharpness at %d is %3.6f", targetZPosition, metric);
        if (metric > bestMetricSoFar) {
            bestMetricSoFar = metric;
            bestPositionSoFar = targetZPosition;
        }
        [samples addObject:[NSNumber numberWithFloat:metric]];
        [self _recordNewCurrentIterationPosition:targetZPosition Metric:metric];
    }

    // Calculate slope of best-fit
    float sumY = 0.0;
    float sumX = 0.0;
    float sumXY = 0.0;
    float sumX2 = 0.0;
    float sumY2 = 0.0;
    for (int i=0; i<[samples count]; ++i) {
        float value = [[samples objectAtIndex:i] floatValue];
        sumX = sumX + i;
        sumY = sumY + value;
        sumXY = sumXY + (i * value);
        sumX2 = sumX2 + (i * i);
        sumY2 = sumY2 + (value * value);
    }
    float slope = (([samples count] * sumXY) - (sumX * sumY)) / (([samples count] * sumX2) - (sumX * sumX));

    // If slope is 0, move to best position and return success
    // It would be great if we could go over the slope calculatiion
    if (slope == 0.0) {
        return TBScopeFocusManagerResultSuccess;
    }

    // If direction is 0, set direction based on slope
    if (direction == 0) {
        if (slope > 0.0) {
            direction = 1;
        } else {
            direction = -1;
        }
    }

    // If we're climbing up and slope is decreasing
    if (direction > 0 && slope < 0) {
        return TBScopeFocusManagerResultSuccess;
    }

    // If we're climbing down and slope is increasing
    if (direction < 0 && slope > 0) {
        return TBScopeFocusManagerResultSuccess;
    }

    // Record lastGoodMetric/position and continue climbing
    if (direction > 0) {  // If we're climbing up
        // Move stepsPerSlice steps up
        int targetZPosition = startZPosition + slicesPerIteration*stepsPerSlice;
        [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:targetZPosition];
        [[TBScopeHardware sharedHardware] waitForStage];
    } else {  // If we're climbing down
        // Move stepsPerSlice steps down
        int targetZPosition = startZPosition - slicesPerIteration*stepsPerSlice;
        [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:targetZPosition];
        [[TBScopeHardware sharedHardware] waitForStage];
    }
    return [self _hillClimbInSlicesOf:stepsPerSlice
                   slicesPerIteration:slicesPerIteration
                          inDirection:direction
                      withMinPosition:minPosition
                          maxPosition:maxPosition];
}

- (void)_recordNewCurrentIterationPosition:(int)position Metric:(float)metric
{
    // Propagate to currentIterationBestPosition/Metric if applicable
    if (metric > self.currentIterationBestMetric) {
        self.currentIterationBestMetric = metric;
        self.currentIterationBestPosition = position;
        [TBScopeData CSLog:[NSString stringWithFormat:@"Best focus position for current iteration is %d with metric %f",position,metric] inCategory:@"CAPTURE"];
    }
}

- (void)_resetCurrentIterationStats
{
    self.currentIterationBestPosition = -1;
    self.currentIterationBestMetric = -1.0;
}

- (void)_updateLastGoodPositionAndMetric
{
    self.lastGoodPosition = self.currentIterationBestPosition;
    self.lastGoodMetric = self.currentIterationBestMetric;
}

- (float)_mean:(NSArray *)array
{
    float total = 0.0;
    for (NSNumber *value in array) {
        total = total + [value floatValue];
    }
    return total / [array count];
}

- (float)_stdev:(NSArray *)array
{
    float mean = [self _mean:array];
    float sumOfSquaredDifferences = 0.0;
    for(NSNumber *value in array)
    {
        float difference = [value floatValue] - mean;
        sumOfSquaredDifferences += difference * difference;
    }
    return sqrt(sumOfSquaredDifferences / [array count]);
}

// Not sure whether pausing briefly after moving the lens up/down helps
// get a less noisy image quality metric. We'll set it arbitrarily for
// now, but would be worth some investigation later.
// ...testing different values
- (void)pauseForSettling
{
    float sleepTime =[[NSUserDefaults standardUserDefaults] floatForKey:@"FocusSettlingTime"];
    sleepTime = 0.3;
    [NSThread sleepForTimeInterval:sleepTime];
}

@end
