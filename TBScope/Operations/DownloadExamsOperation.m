//
//  DownloadExamsOperation.m
//  TBScope
//
//  Created by Jason Ardell on 4/2/16.
//  Copyright © 2016 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "DownloadExamsOperation.h"
#import "GoogleDriveSync.h"
#import "Promise+Hang.h"

@implementation DownloadExamsOperation

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
        NSLog(@"Not downloading exam because DownloadEnabled config setting is turned off");
        [self completeOperation];
        return;
    }
    
    // Create a temporary managed object context
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    moc.parentContext = [[TBScopeData sharedData] managedObjectContext];
    
    // Get a list of images to upload
    NSArray *objectIDs = [self _getObjectIDsToDownload:moc];
    
    // Download exams in batches of _batchSize
    [self _downloadObjectsWithIDs:objectIDs
                          context:moc];
}

- (NSArray *)_getObjectIDsToDownload:(NSManagedObjectContext *)moc
{
    [TBScopeData CSLog:@"Fetching new/updated exams from Google Drive." inCategory:@"SYNC"];
    
    // Find all slides, with the most recent first
    GoogleDriveService *service = [GoogleDriveService sharedService];
    NSMutableArray *fileIDs = [[NSMutableArray alloc] init];
    [moc performBlockAndWait:^{
        // THIS QUERY IS NOT DOWNLOADING FILES THAT WEREN'T UPLOADED FROM APP...WHY!!???
        // See here for answer: http://stackoverflow.com/questions/15283461/google-drive-file-list-api-returns-an-empty-array-for-items
        // Basically our Google Drive account is app-owned, so the application can
        // only see items that it created. So if you create a file manually then
        // it will never be returned from this query.
        GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];

        //the problem with fetching only GD records since this ipad's last sync date is if they were modified before this date but uploaded after, this would not pick them up
        //simplest solution is to just check ALL the JSON objects in GD, but that will cause more network chatter. not sure a straightforward workaround.
        //if (ONLY_CHECK_RECORDS_SINCE_LAST_FULL_SYNC)
        //    query.q = [NSString stringWithFormat:@"modifiedDate > '%@' and mimeType='application/json'",[GTLDateTime dateTimeWithDate:lastFullSync timeZone:[NSTimeZone systemTimeZone]].RFC3339String];
        //else
        NSString *parentDirIdentifier = [[NSUserDefaults standardUserDefaults] valueForKey:@"RemoteDirectoryIdentifier"];
        if (!parentDirIdentifier) parentDirIdentifier = @"root";
        query.q = [NSString stringWithFormat:@"'%@' in parents AND mimeType='application/json' AND trashed=false", parentDirIdentifier];
        query.includeDeleted = false;
        query.includeSubscribed = true;
        PMKPromise *promise = [service executeQueryWithTimeout:query]
            .then(^(GTLDriveFileList *files) {
                return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
                    NSString *message = [NSString stringWithFormat:@"Fetched %ld exam JSON files from Google Drive.", (long)files.items.count];
                    [TBScopeData CSLog:message inCategory:@"SYNC"];
                    
                    [moc performBlock:^{
                        for (GTLDriveFile* file in files) {
                            // check if there is a corresponding record in CD for this googleFileID
                            NSPredicate* pred = [NSPredicate predicateWithFormat:@"(googleDriveFileID == %@)", file.identifier];
                            NSArray* results = [CoreDataHelper searchObjectsForEntity:@"Exams"
                                                                        withPredicate:pred
                                                                           andSortKey:@"dateModified"
                                                                     andSortAscending:YES
                                                                           andContext:moc];
                            if (results.count==0) {
                                NSLog(@"Adding new exam %@ to download queue. server timestamp: %@, fileID: %@", file.title, file.modifiedDate.date, file.identifier);
                                [fileIDs addObject:[file identifier]];
                            } else {
                                Exams* ex = (Exams*)[results firstObject];
                                if ([[TBScopeData dateFromString:ex.dateModified] timeIntervalSinceDate:file.modifiedDate.date]<0) {
                                    NSLog(@"Adding modified exam %@ to download queue. server timestamp: %@, local timestamp: %@, fileId: %@", file.title, [TBScopeData stringFromDate:file.modifiedDate.date], ex.dateModified, file.identifier);
                                    [fileIDs addObject:[file identifier]];
                                }
                            }
                        }
                        NSString *message = [NSString stringWithFormat:@"Added %lu exams to download queue.", (unsigned long)[fileIDs count]];
                        [TBScopeData CSLog:message inCategory:@"SYNC"];
                        resolve(nil);
                    }];
                }];
            }).catch(^(NSError *error) {
                NSString *message = [NSString stringWithFormat:@"An error occured while querying Google Drive: %@", error.description];
                [TBScopeData CSLog:message inCategory:@"SYNC"];
            });

        // Wait until we've gathered all the fileIDs
        [PMKPromise hang:promise];
    }];
    
    return fileIDs;
}

- (void)_downloadObjectsWithIDs:(NSArray *)fileIDs
                        context:(NSManagedObjectContext *)moc
{
    GoogleDriveService *gds = [GoogleDriveService sharedService];

    // Loop through objectIDs in increments of _batchSize
    int processedSoFar = 0;
    for (NSString *fileID in fileIDs) {
        // Load the image
        [moc performBlockAndWait:^{
            PMKPromise *promise = [Exams downloadFromGoogleDrive:fileID
                                            managedObjectContext:moc
                                              googleDriveService:gds];
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
