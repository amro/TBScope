//
//  GoogleDriveSync.m
//  TBScope
//
//  Created by Frankie Myers on 1/28/14.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "GoogleDriveSync.h"
#import <PromiseKit/Promise+Join.h>
#import "PMKPromise+NoopPromise.h"
#import "TBScopeImageAsset.h"
#import "GoogleDriveService.h"

NSString *const kGoogleDriveSyncErrorDomain = @"GoogleDriveSyncErrorDomain";

//deprecated
static BOOL previousSyncHadNoChanges = NO; //to start, we assume things are NOT in sync
static NSDate* previousSyncDate = nil;

BOOL _hasAttemptedLogUpload;

@implementation GoogleDriveSync

+ (id)sharedGDS {
    static GoogleDriveSync *newGDS = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        newGDS = [[self alloc] initPrivate];
    });
    return newGDS;
}

- (instancetype)init
{
    [NSException raise:@"Singleton" format:@"Use +[GoogleDriveService sharedService]"];
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    
    if (self) {
        self.examUploadQueue = [[NSMutableArray alloc] init];
        self.examDownloadQueue = [[NSMutableArray alloc] init];
        self.imageUploadQueue = [[NSMutableArray alloc] init];
        self.imageDownloadQueue = [[NSMutableArray alloc] init];

        // Attach event listeners
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(uploadImage:)
                                                     name:@"UploadImage"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(doSync)
                                                     name:@"AnalysisResultsSaved"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNetworkChange:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];

        // Set up reachability listener
        self.reachability = [Reachability reachabilityForInternetConnection];
        [self.reachability startNotifier];
        
        self.syncEnabled = YES;
        self.isSyncing = NO;
    }

    return self;
}


- (void) handleNetworkChange:(NSNotification *)notice
{
    NetworkStatus remoteHostStatus = [self.reachability currentReachabilityStatus];
    if (remoteHostStatus == NotReachable) {
        [TBScopeData CSLog:@"No Connection" inCategory:@"SYNC"];
    } else if (remoteHostStatus == ReachableViaWiFi) {
        [TBScopeData CSLog:@"WiFi Connected" inCategory:@"SYNC"];
        [self doSync];
    } else if (remoteHostStatus == ReachableViaWWAN) {
        [TBScopeData CSLog:@"Cell WWAN Connected" inCategory:@"SYNC"];
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"WifiSyncOnly"]) {
            [self doSync];
        }
    }
}

- (BOOL) isOkToSync
{
    int networkStatus = (int)[self.reachability currentReachabilityStatus];
    GoogleDriveService *gdService = [[GoogleDriveService alloc] init];
    BOOL isLoggedIn = [gdService isLoggedIn];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"WifiSyncOnly"]) {
        return (networkStatus == ReachableViaWiFi && isLoggedIn);
    } else {
        return (networkStatus != NotReachable && isLoggedIn);
    }
}

- (void)doSync {
    // Don't begin another sync if we're already syncing
    if (self.isSyncing) return;

    //[TBScopeData CSLog:@"Checking if we should sync..." inCategory:@"SYNC"];

    _hasAttemptedLogUpload = NO;

    // if google unreachable or sync disabled, abort this operation and call
    // again some time later
    if (self.syncEnabled==NO || [self isOkToSync]==NO) {
        [NSTimer scheduledTimerWithTimeInterval:[[NSUserDefaults standardUserDefaults] floatForKey:@"SyncRetryInterval"]
                                         target:self
                                       selector:@selector(doSync)
                                       userInfo:nil
                                        repeats:NO];
        [TBScopeData CSLog:@"Google Drive unreachable or sync disabled. Cannot build queue. Will retry."
                inCategory:@"SYNC"];
        return;
    }

    NSString *message = [NSString stringWithFormat:@"Sync initiated with Google Drive account: %@", [[[GoogleDriveService alloc] init] userEmail]];
    [TBScopeData CSLog:message inCategory:@"SYNC"];
    self.isSyncing = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncStarted" object:nil];

    // Sync in a background thread so we don't block the UI
    NSManagedObjectContext *tmpMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    tmpMOC.parentContext = [[TBScopeData sharedData] managedObjectContext];
    [tmpMOC performBlock:^{
        NSMutableArray *enqueueingPromises = [[NSMutableArray alloc] init];
        NSPredicate* pred;
        NSMutableArray* results;

        /////////////////////////
        //push images
        if ([self uploadIsEnabled]) {
            [TBScopeData CSLog:@"Fetching new images from core data." inCategory:@"SYNC"];
            // Find all slides, with the most recent first
            results = [CoreDataHelper searchObjectsForEntity:@"Slides"
                                               withPredicate:nil
                                                  andSortKey:@"dateScanned"
                                            andSortAscending:NO
                                                  andContext:tmpMOC];
            int imageUploadsEnqueued = 0;
            for (Slides *slide in results) {
                if (slide.slideAnalysisResults) {  // If slide is analyzed
                    // Find the top 10 ROIs belonging to the slide
                    NSFetchRequest *request = [[NSFetchRequest alloc] init];
                    NSEntityDescription *entity = [NSEntityDescription entityForName:@"ROIs"
                                                              inManagedObjectContext:tmpMOC];
                    [request setEntity:entity];
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"imageAnalysisResult.image.slide = %@", slide];
                    [request setPredicate:predicate];
                    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"score" ascending:NO];
                    [request setSortDescriptors:@[sort]];
                    [request setFetchLimit:10];
                    NSError *error = nil;
                    NSMutableArray *rois = [[tmpMOC executeFetchRequest:request error:&error] mutableCopy];
                    for (ROIs *roi in rois) {
                        // Upload the associated image for each
                        Images *image = [[roi imageAnalysisResult] image];
                        if ([self.imageUploadQueue indexOfObject:image] == NSNotFound) {  // if it's not already in the queue
                            [self.imageUploadQueue addObject:image];
                            imageUploadsEnqueued++;
                        }
                    }
                } else {  // Otherwise upload all non-remote images
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(slide = %@) && (googleDriveFileID = nil) && (path != nil)", slide];
                    NSArray *images = [CoreDataHelper searchObjectsForEntity:@"Images"
                                                       withPredicate:predicate
                                                          andSortKey:@"fieldNumber"
                                                    andSortAscending:YES
                                                          andContext:tmpMOC];
                    for (Images *image in images) {
                        if ([self.imageUploadQueue indexOfObject:image] == NSNotFound) {  // if it's not already in the queue
                            [self.imageUploadQueue addObject:image];
                            imageUploadsEnqueued++;
                        }
                    }
                }
            }
            [TBScopeData CSLog:[NSString stringWithFormat:@"Added %d images to upload queue.", imageUploadsEnqueued] inCategory:@"SYNC"];
        }

        /////////////////////////
        // push exams
        if ([self uploadIsEnabled]) {
            [TBScopeData CSLog:@"Fetching new/modified exams from core data." inCategory:@"SYNC"];
            //TODO: it probably makes more sense to just store a "hasUpdates" flag in CD. this gets set whenever exam changes, reset when its uploaded. then can do away w/ previousSyncHadNoChanges
            pred = [NSPredicate predicateWithFormat:@"(synced == NO) || (googleDriveFileID = nil)"];
            results = [CoreDataHelper searchObjectsForEntity:@"Exams" withPredicate:pred andSortKey:@"dateModified" andSortAscending:YES andContext:tmpMOC];
            int examUploadsEnqueued = 0;
            for (Exams* ex in results) {
                if ([self.examUploadQueue indexOfObject:ex]==NSNotFound) {  //if it's not already in the queue
                    if (ex.googleDriveFileID==nil) {
                        NSLog(@"Adding new exam %@ to upload queue. local timestamp: %@", ex.examID, ex.dateModified);
                        [self.examUploadQueue addObject:ex];
                        examUploadsEnqueued++;
                        // previousSyncHadNoChanges = NO;
                    } else {  // exam exists on both client and server, so check dates
                        // get modified date on server
                        GoogleDriveService *service = [[GoogleDriveService alloc] init];
                        PMKPromise *promise = [service getMetadataForFileId:ex.googleDriveFileID]
                            .then(^(GTLDriveFile *remoteFile){
                                [tmpMOC performBlock:^{
                                    if ([[TBScopeData dateFromString:ex.dateModified] timeIntervalSinceDate:remoteFile.modifiedDate.date] > 0) {
                                        NSLog(
                                              @"Adding modified exam %@ to upload queue. server timestamp: %@, local timestamp: %@",
                                              ex.examID,
                                              [TBScopeData stringFromDate:remoteFile.modifiedDate.date],
                                              ex.dateModified
                                              );
                                        [self.examUploadQueue addObject:ex];
                                        previousSyncHadNoChanges = NO;
                                    }
                                }];
                            }).catch(^(NSError *error) {
                                if (error.code==404) {  // the file referenced by this exam isn't present on server, so remove this google drive ID
                                    [TBScopeData CSLog:@"Requested JSON file doesn't exist in Google Drive (error 404), so removing this reference."
                                            inCategory:@"SYNC"];

                                    [tmpMOC performBlock:^{
                                        // remove all google drive references
                                        ex.googleDriveFileID = nil;
                                        for (Slides* sl in ex.examSlides) {
                                            sl.roiSpriteGoogleDriveFileID = nil;
                                            for (Images* im in sl.slideImages)
                                                im.googleDriveFileID = nil;
                                        }

                                        // Save exam/images
                                        NSError *tmpMOCSaveError;
                                        if (![tmpMOC save:&tmpMOCSaveError]) {
                                            NSLog(@"Error saving temporary managed object context.");
                                        }
                                        [[TBScopeData sharedData] saveCoreData];
                                    }];
                                } else {
                                    NSString *message = [NSString stringWithFormat:@"An error occured while querying Google Drive: %@", error.description];
                                    [TBScopeData CSLog:message inCategory:@"SYNC"];
                                }
                            });
                        [enqueueingPromises addObject:promise];
                    }
                } //next exam
            }
            [TBScopeData CSLog:[NSString stringWithFormat:@"Added %d new exams to upload queue.", examUploadsEnqueued] inCategory:@"SYNC"];
        }

        /////////////////////////
        // pull exams
        if ([self downloadIsEnabled]) {
            // get all exams on server
            [TBScopeData CSLog:@"Fetching new/modified exams from Google Drive." inCategory:@"SYNC"];

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
            GoogleDriveService *service = [[GoogleDriveService alloc] init];
            PMKPromise *promise = [service executeQueryWithTimeout:query]
                .then(^(GTLDriveFileList *files) {
                    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
                        NSString *message = [NSString stringWithFormat:@"Fetched %ld exam JSON files from Google Drive.", (long)files.items.count];
                        [TBScopeData CSLog:message inCategory:@"SYNC"];
                        [tmpMOC performBlock:^{
                            int examDownloadsEnqueued = 0;
                            for (GTLDriveFile* file in files) {
                                if ([self.examDownloadQueue indexOfObject:file]==NSNotFound) {  //not already in the queue
                                    // check if there is a corresponding record in CD for this googleFileID
                                    NSPredicate* pred = [NSPredicate predicateWithFormat:@"(googleDriveFileID == %@)", file.identifier];
                                    NSArray* result = [CoreDataHelper searchObjectsForEntity:@"Exams" withPredicate:pred andSortKey:@"dateModified" andSortAscending:YES andContext:tmpMOC];
                                    if (result.count==0) {
                                        NSLog(@"Adding new exam %@ to download queue. server timestamp: %@, fileID: %@", file.title, file.modifiedDate.date, file.identifier);
                                        [self.examDownloadQueue addObject:file];
                                        examDownloadsEnqueued++;
                                        // previousSyncHadNoChanges = NO;
                                    } else {
                                        Exams* ex = (Exams*)result[0];
                                        if ([[TBScopeData dateFromString:ex.dateModified] timeIntervalSinceDate:file.modifiedDate.date]<0) {
                                            NSLog(@"Adding modified exam %@ to download queue. server timestamp: %@, local timestamp: %@, fileId: %@", file.title, [TBScopeData stringFromDate:file.modifiedDate.date], ex.dateModified, file.identifier);
                                            [self.examDownloadQueue addObject:file];
                                            examDownloadsEnqueued++;
                                            // previousSyncHadNoChanges = NO;
                                        }
                                    }
                                }
                            }
                            [TBScopeData CSLog:[NSString stringWithFormat:@"Added %d exams to download queue.", examDownloadsEnqueued] inCategory:@"SYNC"];
                            resolve(nil);
                        }];
                    }];
                }).catch(^(NSError *error) {
                    NSString *message = [NSString stringWithFormat:@"An error occured while querying Google Drive: %@", error.description];
                    [TBScopeData CSLog:message inCategory:@"SYNC"];
                });
            [enqueueingPromises addObject:promise];
        }

        /////////////////////////
        // pull images
        if ([self downloadIsEnabled]) {
            // search CD for images with empty path
            [TBScopeData CSLog:@"Fetching new images from Google Drive." inCategory:@"SYNC"];
            pred = [NSPredicate predicateWithFormat:@"(path = nil) && (googleDriveFileID != nil)"];
            NSArray *sortDescriptors = @[
                [[NSSortDescriptor alloc] initWithKey:@"slide.exam.dateModified" ascending:NO],
                [[NSSortDescriptor alloc] initWithKey:@"fieldNumber" ascending:YES],
            ];
            results = [CoreDataHelper searchObjectsForEntity:@"Images"
                                               withPredicate:pred
                                          andSortDescriptors:sortDescriptors
                                                  andContext:tmpMOC];
            int imageDownloadsEnqueued = 0;
            for (Images* im in results) {
                if ([self.imageDownloadQueue indexOfObject:im]==NSNotFound) {
                    NSLog(@"Adding image #%d from slide #%d from exam %@ to download queue", im.fieldNumber, im.slide.slideNumber, im.slide.exam.examID);

                    [self.imageDownloadQueue addObject:im];
                    imageDownloadsEnqueued++;
                    // previousSyncHadNoChanges = NO;
                }
                [tmpMOC refreshObject:im mergeChanges:NO];
            }
            [TBScopeData CSLog:[NSString stringWithFormat:@"Added %d images to download queue", imageDownloadsEnqueued] inCategory:@"SYNC"];
        }

        // Start processing queues. We wait to dispatch this for 5s because we want
        // to make sure the server has a chance to respond to the requests made
        // above (and all the queues become populated)
        [PMKPromise join:enqueueingPromises]
            .then(^{ [self processTransferQueues]; });
    }];
}

//uploads/downloads the next item in the upload queue
- (void)processTransferQueues
{
    void (^completionBlock)(NSError*) = ^(NSError* error){
        //log the error, but continue on with queue
        if (error!=nil) {
            [TBScopeData CSLog:[NSString stringWithFormat:@"Error while processing queue: %@",error.description] inCategory:@"SYNC"];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncUpdate" object:nil];

        //call process queue again to execute the next item in queue
        [self processTransferQueues];
    };
    
    static BOOL isPaused = NO;
    
    //if network unreachable or sync disabled, call this function again later (it will pick up where it left off)
    //this is ideal for short-term network drops, since it means we don't have to go through the whole doSync process again
    //when it reconnects
    if (self.syncEnabled==NO || [self isOkToSync]==NO) {
            [NSTimer scheduledTimerWithTimeInterval:[[NSUserDefaults standardUserDefaults] floatForKey:@"SyncRetryInterval"] target:self selector:@selector(processTransferQueues) userInfo:nil repeats:NO];
        [TBScopeData CSLog:@"Google Drive unreachable or sync disabled while processing queue. Will retry." inCategory:@"SYNC"];
        isPaused = YES;
        self.isSyncing = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncStopped" object:nil];

        return;
    } else {
        if (isPaused) {
            self.isSyncing = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncStarted" object:nil];

        }
        isPaused = NO;
    }
    
    [TBScopeData CSLog:@"Processing next item in sync queue..." inCategory:@"SYNC"];
    if (self.imageUploadQueue.count>0 && self.syncEnabled && [self uploadIsEnabled]) {
        Images *image = self.imageUploadQueue[0];
        [self.imageUploadQueue removeObjectAtIndex:0];
        [self uploadImage:image completionHandler:completionBlock];
    } else if (self.examUploadQueue.count>0 && self.syncEnabled && [self uploadIsEnabled]) {
        Exams *exam = self.examUploadQueue[0];
        [self.examUploadQueue removeObjectAtIndex:0];
        [self uploadExam:exam completionHandler:completionBlock];
    } else if (self.examDownloadQueue.count>0 && self.syncEnabled && [self downloadIsEnabled]) {
        GTLDriveFile *file = self.examDownloadQueue[0];
        [self.examDownloadQueue removeObjectAtIndex:0];
        [self downloadExam:file completionHandler:completionBlock];
    } else if (self.imageDownloadQueue.count>0 && self.syncEnabled && [self downloadIsEnabled]) {
        Images *image = self.imageDownloadQueue[0];
        [self.imageDownloadQueue removeObjectAtIndex:0];
        [self downloadImage:image completionHandler:completionBlock];
    } else if (_hasAttemptedLogUpload==NO && self.syncEnabled) {
        _hasAttemptedLogUpload = YES;
        [self uploadLogWithCompletionHandler:completionBlock];
    } else {
        self.isSyncing = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncUpdate" object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncStopped" object:nil];
        [TBScopeData CSLog:@"upload/download queues empty or sync disabled" inCategory:@"SYNC"];

        //schedule the next sync iteration some time in the future (note: might want to make this some kind of service which runs based on OS notifications)
        float syncInterval = [[NSUserDefaults standardUserDefaults] floatForKey:@"SyncInterval"]*60;
        [NSTimer scheduledTimerWithTimeInterval:syncInterval
                                         target:self
                                       selector:@selector(doSync)
                                       userInfo:nil
                                        repeats:NO];
    }
}

- (void)uploadImage:(Images*)image completionHandler:(void(^)(NSError*))completionBlock
{
    // Don't upload if "UploadEnabled" config option is turned off
    if (![self uploadIsEnabled]) {
        NSLog(@"Not uploading image because UploadEnabled config setting is turned off");
        completionBlock(nil);
        return;
    }

    // Create a child managed object context
    __block NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    moc.parentContext = [[TBScopeData sharedData] managedObjectContext];

    // Load a local copy of the image for this thread
    __block Images *localImage;
    [moc performBlockAndWait:^{
        localImage = [moc objectWithID:[image objectID]];
    }];

    // Upload the image
    GoogleDriveService *gds = [[GoogleDriveService alloc] init];
    [localImage uploadToGoogleDrive:gds]
        .then(^{
            return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
                [moc performBlock:^{
                    NSError *error;
                    if (![moc save:&error]) {
                        NSLog(@"Error saving temporary managed object context");
                    }
                    resolve(nil);
                }];
            }];
        }).then(^{
            [[TBScopeData sharedData] saveCoreData];
            completionBlock(nil);
        }).catch(^(NSError *error) {
            completionBlock(error);
        });
}

- (void)uploadExam:(Exams*)exam completionHandler:(void(^)(NSError*))completionBlock
{
    // Don't upload if "UploadEnabled" config option is turned off
    if (![self uploadIsEnabled]) {
        NSLog(@"Not uploading exam because UploadEnabled config setting is turned off");
        completionBlock(nil);
        return;
    }

    // Create a child managed object context
    __block NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    moc.parentContext = [[TBScopeData sharedData] managedObjectContext];

    // Load a local copy of the exam for this thread
    __block Exams *localExam;
    [moc performBlockAndWait:^{
        localExam = [moc objectWithID:[exam objectID]];
    }];

    GoogleDriveService *gds = [[GoogleDriveService alloc] init];
    [localExam uploadToGoogleDrive:gds]
        .then(^{
            return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
                [moc performBlock:^{
                    NSError *error;
                    if (![moc save:&error]) {
                        NSLog(@"Error saving temporary managed object context");
                    }
                    resolve(nil);
                }];
            }];
        }).then(^{
            [[TBScopeData sharedData] saveCoreData];
            completionBlock(nil);
        }).catch(^(NSError *error) {
            completionBlock(error);
        });
}

- (void)downloadExam:(GTLDriveFile*)file completionHandler:(void(^)(NSError*))completionBlock
{
    // Don't download if "DownloadEnabled" config option is turned off
    if (![self downloadIsEnabled]) {
        NSLog(@"Not downloading exam because DownloadEnabled config setting is turned off");
        completionBlock(nil);
        return;
    }

    // Set up dependencies
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    moc.parentContext = [[TBScopeData sharedData] managedObjectContext];
    GoogleDriveService *gds = [[GoogleDriveService alloc] init];

    // Download
    [Exams downloadFromGoogleDrive:file.identifier
              managedObjectContext:moc
                googleDriveService:gds]
        .then(^{
            return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
                [moc performBlock:^{
                    NSError *error;
                    if (![moc save:&error]) {
                        NSLog(@"Error saving temporary managed object context");
                    }
                    resolve(nil);
                }];
            }];
        }).then(^{
            [[TBScopeData sharedData] saveCoreData];
            completionBlock(nil);
        }).catch(^(NSError *error) {
            completionBlock(error);
        });
}

- (void)downloadImage:(Images*)image completionHandler:(void(^)(NSError*))completionBlock
{
    // Don't download if "DownloadEnabled" config option is turned off
    if (![self downloadIsEnabled]) {
        NSLog(@"Not downloading image because DownloadEnabled config setting is turned off");
        completionBlock(nil);
        return;
    }

    // Set up dependencies
    __block NSManagedObjectContext *moc;
    __block Images *localImage;
    __block GoogleDriveService *gds = [[GoogleDriveService alloc] init];
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        moc.parentContext = [[TBScopeData sharedData] managedObjectContext];
        [moc performBlockAndWait:^{
            localImage = [moc objectWithID:[image objectID]];
        }];
    });

    [localImage downloadFromGoogleDrive:gds]
        .then(^{
            return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
                [moc performBlock:^{
                    NSError *error;
                    if (![moc save:&error]) {
                        NSLog(@"Error saving temporary managed object context");
                    }
                    resolve(nil);
                }];
            }];
        }).then(^{
            [[TBScopeData sharedData] saveCoreData];
            completionBlock(nil);
        }).catch(^(NSError *error) {
            completionBlock(error);
        });
}

// Upload any recent log entries to a new text file
- (void)uploadLogWithCompletionHandler:(void(^)(NSError*))completionBlock
{
    NSManagedObjectContext *tmpMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    tmpMOC.parentContext = [[TBScopeData sharedData] managedObjectContext];
    
    NSPredicate* pred = [NSPredicate predicateWithFormat:@"(synced == NO)"];
    __block NSArray* results;
    [tmpMOC performBlockAndWait:^{
        results = [CoreDataHelper searchObjectsForEntity:@"Logs"
                                           withPredicate:pred
                                              andSortKey:@"date"
                                        andSortAscending:YES
                                              andContext:tmpMOC];
    }];

    if (results.count <= 0) {
        // Nothing to do
        completionBlock(nil);
        return;
    }

    NSLog(@"UPLOADING LOG FILE");

    // Build text file
    __block NSMutableString* outString = [[NSMutableString alloc] init];
    for (Logs* logEntry in results) {
        [tmpMOC performBlockAndWait:^{
            logEntry.synced = YES;
            [outString appendFormat:@"%@\t%@\t%@\n", logEntry.date, logEntry.category, logEntry.entry];
        }];
    }

    // Create a google file object from this image
    GTLDriveFile *file = [GTLDriveFile object];
    file.title = [NSString stringWithFormat:@"%@ - %@.log",
                  [[NSUserDefaults standardUserDefaults] stringForKey:@"CellScopeID"],
                  [TBScopeData stringFromDate:[NSDate date]]];
    file.descriptionProperty = @"Uploaded from CellScope";
    file.mimeType = @"text/plain";
    NSData *data = [outString dataUsingEncoding:NSUTF8StringEncoding];

    // Upload the file
    GoogleDriveService *service = [[GoogleDriveService alloc] init];
    [service uploadFile:file withData:data]
        .then(^(GTLDriveFile *insertedFile) {
            [tmpMOC performBlockAndWait:^{
                // Save
                NSError *tmpMOCSaveError;
                if (![tmpMOC save:&tmpMOCSaveError]) {
                    NSLog(@"Error saving temporary managed object context");
                }
                [[TBScopeData sharedData] saveCoreData];
            }];
            completionBlock(nil);
        }).catch(^(NSError *error) {
            completionBlock(error);
        });
}

- (BOOL)uploadIsEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"UploadEnabled"];
}

- (BOOL)downloadIsEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DownloadEnabled"];
}

@end
