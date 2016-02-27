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
    return (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FocusBroadSweepStepSize"];  // steps
}

- (int)zPositionBroadSweepMax
{
    return (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultFocusZ"] +
            ((int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FocusBroadSweepRange"] / 2) ;
    
}

- (int)zPositionBroadSweepMin
{
    return (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultFocusZ"] -
    ((int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FocusBroadSweepRange"] / 2) ;
}

- (int)zPositionFineSweepStepsPerSlice
{
    return 100;
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

    // If we have a last good position, move there then fine sweep
    if (self.lastGoodPosition != -1) {
        [[TBScopeHardware sharedHardware] moveToX:-1
                                                Y:-1
                                                Z:self.lastGoodPosition
                                   inIncrementsOf:[self zPositionBroadSweepStepsPerSlice]];
        if ([self _fineSweep] == TBScopeFocusManagerResultSuccess) {
            [TBScopeData CSLog:[NSString stringWithFormat:@"Fine sweep successful, best metric = %f, best position = %d", self.currentIterationBestMetric, self.currentIterationBestPosition] inCategory:@"CAPTURE"];
            return TBScopeFocusManagerResultSuccess;
        } else {
            [[TBScopeHardware sharedHardware] moveToX:-1
                                                    Y:-1
                                                    Z:self.lastGoodPosition
                                       inIncrementsOf:[self zPositionBroadSweepStepsPerSlice]];
            return TBScopeFocusManagerResultReturn;
        }
    }

    // Start from a very coarse sweep, then do a finer sweep
    if ([self _coarseSweep] == TBScopeFocusManagerResultSuccess) {
        [self _fineSweep];
        [TBScopeData CSLog:[NSString stringWithFormat:@"Full auto-focus successful, best metric = %f, best position = %d", self.currentIterationBestMetric, self.currentIterationBestPosition] inCategory:@"CAPTURE"];
        return TBScopeFocusManagerResultSuccess;
    } else if (self.lastGoodPosition != -1) {
        [[TBScopeHardware sharedHardware] moveToX:-1
                                                Y:-1
                                                Z:self.lastGoodPosition
                                   inIncrementsOf:[self zPositionBroadSweepStepsPerSlice]];
        [TBScopeData CSLog:@"Auto focus failed, returning to last good position." inCategory:@"CAPTURE"];
        return TBScopeFocusManagerResultReturn;
    }

    // Utter failure to focus, return to starting position
    [[TBScopeHardware sharedHardware] moveToX:-1
                                            Y:-1
                                            Z:startingZPosition
                               inIncrementsOf:[self zPositionBroadSweepStepsPerSlice]];
    [TBScopeData CSLog:@"Auto focus failure" inCategory:@"CAPTURE"];
    return TBScopeFocusManagerResultFailure;
}

- (TBScopeFocusManagerResult)_coarseSweep
{
    [TBScopeData CSLog:@"Starting coarse sweep" inCategory:@"CAPTURE"];

    return [self _sweepFrom:[self zPositionBroadSweepMin]
                         to:[self zPositionBroadSweepMax]
             inIncrementsOf:[self zPositionBroadSweepStepsPerSlice]
         withStdevThreshold:FOCUS_SUCCESS_STDDEV_MULTIPLIER];
}

- (TBScopeFocusManagerResult)_fineSweep
{
    [TBScopeData CSLog:@"Starting fine sweep" inCategory:@"CAPTURE"];

    int currentPosition = [[TBScopeHardware sharedHardware] zPosition];
    int minPosition = currentPosition - 2000;
    int maxPosition = currentPosition + 500;
    int stepIncrement = [self zPositionFineSweepStepsPerSlice];
    return [self _sweepFrom:minPosition
                         to:maxPosition
             inIncrementsOf:stepIncrement
         withStdevThreshold:0.0];
}

- (TBScopeFocusManagerResult)_sweepFrom:(int)minPosition
                                     to:(int)maxPosition
                         inIncrementsOf:(int)stepIncrement
                     withStdevThreshold:(double)stdevThreshold
{
    NSLog(@"Sweeping from %d to %d in increments of %d", minPosition, maxPosition, stepIncrement);

    // Start at minPosition
    [[TBScopeHardware sharedHardware] moveToX:-1
                                            Y:-1
                                            Z:minPosition
                               inIncrementsOf:stepIncrement];

    // For each slice to zPositionBroadSweepMax...
    NSMutableArray *samples = [[NSMutableArray alloc] init];
    NSInteger bestPositionSoFar = nil;
    float bestMetricSoFar = -1.0;
    for (int position=minPosition; position <= maxPosition; position+=stepIncrement)
    {
        // Move into position
        [[TBScopeHardware sharedHardware] moveToX:-1
                                                Y:-1
                                                Z:position
                                   inIncrementsOf:stepIncrement];
        [self pauseForSettling];  // does this help reduce blurring?

        // Gather metric
        float metric = [self currentImageQualityMetric];
        if (metric > bestMetricSoFar) {
            bestMetricSoFar = metric;
            bestPositionSoFar = position;
        }
        [samples addObject:[NSNumber numberWithFloat:metric]];
    }

    // If best metric is more than N stdev from mean, go there and return success
    float mean = [self _mean:samples];
    float stdev = [self _stdev:samples];
    
    if (bestMetricSoFar > mean + stdevThreshold*stdev) {
        [self _recordNewCurrentIterationPosition:bestPositionSoFar
                                          Metric:bestMetricSoFar];
        [[TBScopeHardware sharedHardware] moveToX:-1
                                                Y:-1
                                                Z:bestPositionSoFar
                                   inIncrementsOf:stepIncrement];
        [self _updateLastGoodPositionAndMetric];
        return TBScopeFocusManagerResultSuccess;
    } else {
        return TBScopeFocusManagerResultFailure;
    }
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
    sleepTime = 0.15;
    [NSThread sleepForTimeInterval:sleepTime];
}

@end
