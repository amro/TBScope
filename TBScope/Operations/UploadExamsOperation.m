//
//  UploadExamOperation.m
//  TBScope
//
//  Created by Jason Ardell on 4/2/16.
//  Copyright © 2016 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "UploadExamsOperation.h"
#import "GoogleDriveSync.h"
#import "Promise+Hang.h"

@implementation UploadExamsOperation

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

- (void)main;
{
    if ([self isCancelled]) {
        return;
    }

    // Don't upload if "UploadEnabled" config option is turned off
    if (![GoogleDriveSync uploadIsEnabled]) {
        NSLog(@"Not uploading exam because UploadEnabled config setting is turned off");
        [self completeOperation];
        return;
    }
    
    // Create a temporary managed object context
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    moc.parentContext = [[TBScopeData sharedData] managedObjectContext];

    // Get a list of exams to upload
    NSArray *objectIDs = [self _getObjectIDsToUpload:moc];

    // Upload exams in batches of _batchSize
    [self _uploadObjectsWithIDs:objectIDs
                        context:moc];
}

- (NSArray *)_getObjectIDsToUpload:(NSManagedObjectContext *)moc
{
    [TBScopeData CSLog:@"Fetching new/updated exams from core data." inCategory:@"SYNC"];
    
    // Find all slides, with the most recent first
    GoogleDriveService *service = [GoogleDriveService sharedService];
    NSMutableArray *objectIDs = [[NSMutableArray alloc] init];
    [moc performBlockAndWait:^{
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"(synced == NO) || (googleDriveFileID = nil)"];
        NSMutableArray *results = [CoreDataHelper searchObjectsForEntity:@"Exams"
                                                           withPredicate:pred
                                                              andSortKey:@"dateModified"
                                                        andSortAscending:YES
                                                              andContext:moc];
        for (Exams *ex in results) {
            NSManagedObjectID *objectID = [ex objectID];
            
            if (ex.googleDriveFileID == nil) {
                NSLog(@"Adding new exam %@ to upload queue. local timestamp: %@", ex.examID, ex.dateModified);
                [objectIDs addObject:objectID];
            } else {  // exam exists on both client and server, so check dates
                // get modified date on server
                PMKPromise *promise = [service getMetadataForFileId:ex.googleDriveFileID]
                    .then(^(GTLDriveFile *remoteFile){
                        [moc performBlock:^{
                            if ([[TBScopeData dateFromString:ex.dateModified] timeIntervalSinceDate:remoteFile.modifiedDate.date] > 0) {
                                NSLog(@"Adding modified exam %@ to upload queue. server timestamp: %@, local timestamp: %@",
                                    ex.examID,
                                    [TBScopeData stringFromDate:remoteFile.modifiedDate.date],
                                    ex.dateModified
                                );
                                [objectIDs addObject:objectID];
                            }
                        }];
                    }).catch(^(NSError *error) {
                        if (error.code == 404) {  // the file referenced by this exam isn't present on server, so remove this google drive ID
                            [TBScopeData CSLog:@"Requested JSON file doesn't exist in Google Drive (error 404), so removing this reference."
                                    inCategory:@"SYNC"];

                            [moc performBlock:^{
                                // remove all google drive references
                                ex.googleDriveFileID = nil;
                                for (Slides* sl in ex.examSlides) {
                                    sl.roiSpriteGoogleDriveFileID = nil;
                                    for (Images* im in sl.slideImages)
                                        im.googleDriveFileID = nil;
                                }
                            }];
                        } else {
                            NSString *message = [NSString stringWithFormat:@"An error occured while querying Google Drive: %@", error.description];
                            [TBScopeData CSLog:message inCategory:@"SYNC"];
                        }
                    });
                [PMKPromise hang:promise];
            }
        }
        NSString *message = [NSString stringWithFormat:@"Added %lu new exams to upload queue.", (unsigned long)[objectIDs count]];
        [TBScopeData CSLog:message inCategory:@"SYNC"];
    }];

    return objectIDs;
}

- (void)_uploadObjectsWithIDs:(NSArray *)objectIDs
                      context:(NSManagedObjectContext *)moc
{
    GoogleDriveService *gds = [GoogleDriveService sharedService];

    // Loop through objectIDs in increments of _batchSize
    int processedSoFar = 0;
    for (NSManagedObjectID *objectID in objectIDs) {
        // Load the image
        [moc performBlockAndWait:^{
            Exams *exam = [moc objectWithID:objectID];
            PMKPromise *promise = [exam uploadToGoogleDrive:gds];
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
