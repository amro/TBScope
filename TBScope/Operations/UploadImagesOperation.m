//
//  UploadImagesOperation.m
//  TBScope
//
//  Created by Jason Ardell on 4/2/16.
//  Copyright © 2016 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "UploadImagesOperation.h"
#import "GoogleDriveSync.h"
#import "Promise+Hang.h"

@implementation UploadImagesOperation

- (void)start;
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

- (void)main
{
    if ([self isCancelled]) {
        return;
    }

    // Don't upload if "UploadEnabled" config option is turned off
    if (![GoogleDriveSync uploadIsEnabled]) {
        NSLog(@"Not uploading image because UploadEnabled config setting is turned off");
        [self completeOperation];
        return;
    }

    // Create a temporary managed object context
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    moc.parentContext = [[TBScopeData sharedData] managedObjectContext];

    // Get a list of images to upload
    NSArray *objectIDs = [self _getObjectIDsToUpload:moc];

    // Upload images in batches of _batchSize
    [self _uploadObjectsWithIDs:objectIDs
                        context:moc].then(^{
        [self completeOperation];
    });
}

- (NSArray *)_getObjectIDsToUpload:(NSManagedObjectContext *)moc
{
    [TBScopeData CSLog:@"Fetching new/updated images from core data." inCategory:@"SYNC"];

    // Find all slides, with the most recent first
    NSMutableArray *objectIDs = [[NSMutableArray alloc] init];
    [moc performBlockAndWait:^{
        NSMutableArray *results = [CoreDataHelper searchObjectsForEntity:@"Slides"
                                                           withPredicate:nil
                                                              andSortKey:@"dateScanned"
                                                        andSortAscending:NO
                                                              andContext:moc];

        for (Slides *slide in results) {
            NSArray *imagesToUpload = [slide imagesToUpload];
            for (Images *image in imagesToUpload) {
                NSManagedObjectID *objectID = [image objectID];
                [objectIDs addObject:objectID];

                // Maybe we need to do this...
                // [moc refreshObject:image mergeChanges:NO];
            }
            
            // Maybe we need to do this so memory gets reclaimed...
            // [moc refreshObject:slide mergeChanges:NO];
        }
        NSString *message = [NSString stringWithFormat:@"Added %lu images to upload queue.", (unsigned long)[objectIDs count]];
        [TBScopeData CSLog:message inCategory:@"SYNC"];
    }];

    return objectIDs;
}

- (PMKPromise *)_uploadObjectsWithIDs:(NSArray *)objectIDs
                      context:(NSManagedObjectContext *)moc
{
    GoogleDriveService *gds = [GoogleDriveService sharedService];

    // Loop through objectIDs in increments of _batchSize
    int processedSoFar = 0;
    __block PMKPromise *promise = [PMKPromise promiseWithValue:nil];
    for (NSManagedObjectID *objectID in objectIDs) {
        // Load the image
        [moc performBlockAndWait:^{
            Images *image = [moc objectWithID:objectID];
            promise = promise.then(^{ return [image uploadToGoogleDrive:gds]; });
        }];
        processedSoFar++;

        // Save if we've just processed an element that's a multiple
        // of _batchSize
        if (processedSoFar % [self _batchSize] == 0) {
            [self _save:moc];
        }
    }

    return promise.then(^{
        [self _save:moc];
        return [PMKPromise promiseWithValue:nil];
    });
}

- (int)_batchSize
{
    return 1000;
}

- (void)_save:(NSManagedObjectContext *)moc
{
    [moc performBlock:^{
        if ([moc hasChanges]) {
            NSError *error;
            [moc save:&error];
        }

        // Reduce memory consumption
        for (NSManagedObject *mo in [moc registeredObjects]) {
            [moc refreshObject:mo mergeChanges:NO];
        }
    }];
    [[TBScopeData sharedData] saveCoreData];
}

- (BOOL)isAsynchronous;
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
