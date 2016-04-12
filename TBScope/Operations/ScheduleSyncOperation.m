//
//  ScheduleSyncOperation.m
//  TBScope
//
//  Created by Jason Ardell on 4/3/16.
//  Copyright © 2016 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "ScheduleSyncOperation.h"
#import "GoogleDriveSync.h"

@implementation ScheduleSyncOperation

- (void) start;
{
    if ([self isCancelled])
    {
        // Move the operation to the finished state if it is canceled.
        [self willChangeValueForKey:@"isFinished"];
        self._finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    // If the operation is not canceled, begin executing the task.
    [self willChangeValueForKey:@"isExecuting"];
    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    self._executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void) main;
{
    if ([self isCancelled]) {
        return;
    }

    // Schedule the next sync iteration some time in the future (note: might
    // want to make this some kind of service which runs based on OS
    // notifications)
    NSLog(@"Running ScheduleSyncOperation.");
    dispatch_async(dispatch_get_main_queue(), ^{
        float syncInterval = [[NSUserDefaults standardUserDefaults] floatForKey:@"SyncInterval"]*60;
        syncInterval = 3.0;  // TODO: remove me after testing
        GoogleDriveSync *gds = [GoogleDriveSync sharedGDS];
        [NSTimer scheduledTimerWithTimeInterval:syncInterval
                                         target:gds
                                       selector:@selector(doSync)
                                       userInfo:nil
                                        repeats:NO];
        [self completeOperation];
    });
}

- (BOOL) isAsynchronous;
{
    return YES;
}

- (BOOL)isExecuting {
    return self._executing;
}

- (BOOL)isFinished {
    return self._finished;
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    
    self._executing = NO;
    self._finished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

@end
