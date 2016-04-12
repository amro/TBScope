//
//  DownloadImagesOperation.m
//  TBScope
//
//  Created by Jason Ardell on 4/2/16.
//  Copyright © 2016 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "DownloadImagesOperation.h"
#import "GoogleDriveSync.h"
#import "Promise+Hang.h"

@implementation DownloadImagesOperation

- (void)start
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

    // Don't download if "DownloadEnabled" config option is turned off
    if (![GoogleDriveSync downloadIsEnabled]) {
        NSLog(@"Not downloading image because DownloadEnabled config setting is turned off");
        [self completeOperation];
        return;
    }

    // Create a temporary managed object context
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    moc.parentContext = [[TBScopeData sharedData] managedObjectContext];

    // Get a list of images to upload
    NSArray *objectIDs = [self _getObjectIDsToDownload:moc];

    // Download images in batches of _batchSize
    [self _downloadObjectsWithIDs:objectIDs
                          context:moc];
}

- (NSArray *)_getObjectIDsToDownload:(NSManagedObjectContext *)moc
{
    [TBScopeData CSLog:@"Fetching new/updated images from Google Drive." inCategory:@"SYNC"];
    
    // Find all slides, with the most recent first
    NSMutableArray *objectIDs = [[NSMutableArray alloc] init];
    [moc performBlockAndWait:^{
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"(path = nil) && (googleDriveFileID != nil)"];
        NSArray *sortDescriptors = @[
                                     [[NSSortDescriptor alloc] initWithKey:@"slide.exam.dateModified" ascending:NO],
                                     [[NSSortDescriptor alloc] initWithKey:@"fieldNumber" ascending:YES],
                                     ];
        NSMutableArray *results = [CoreDataHelper searchObjectsForEntity:@"Images"
                                                           withPredicate:pred
                                                      andSortDescriptors:sortDescriptors
                                                              andContext:moc];
        for (Images* im in results) {
            NSLog(@"Adding image #%d from slide #%d from exam %@ to download queue", im.fieldNumber, im.slide.slideNumber, im.slide.exam.examID);
            NSManagedObjectID *objectID = [im objectID];
            [objectIDs addObject:objectID];
        }
        NSString *message = [NSString stringWithFormat:@"Added %lu images to download queue", (unsigned long)[objectIDs count]];
        [TBScopeData CSLog:message inCategory:@"SYNC"];
    }];
    
    return objectIDs;
}

- (void)_downloadObjectsWithIDs:(NSArray *)objectIDs
                        context:(NSManagedObjectContext *)moc
{
    GoogleDriveService *gds = [GoogleDriveService sharedService];

    // Loop through objectIDs in increments of _batchSize
    int processedSoFar = 0;
    for (NSManagedObjectID *objectID in objectIDs) {
        // Load the image
        [moc performBlockAndWait:^{
            Images *image = [moc objectWithID:objectID];
            PMKPromise *promise = [image downloadFromGoogleDrive:gds];
            [PMKPromise hang:promise];
        }];

        processedSoFar++;

        // Save if we've just processed an element that's a multiple
        // of _batchSize
        if (processedSoFar % [self _batchSize] == 0) {
            [self _save:moc];
        }
    }
    [self _save:moc];

    // Move on to the next task
    [self completeOperation];
}

- (int)_batchSize
{
    return 1000;
}

- (void)_save:(NSManagedObjectContext *)moc
{
    if ([moc hasChanges]) {
        NSError *error;
        [moc save:&error];
    }
    [[TBScopeData sharedData] saveCoreData];
}

- (BOOL)isAsynchronous
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
