//
//  GoogleDriveSync.m
//  TBScope
//
//  Created by Frankie Myers on 1/28/14.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "GoogleDriveSync.h"
#import <PromiseKit/Promise+Join.h>
#import <PromiseKit/Promise+Hang.h>
#import "PMKPromise+NoopPromise.h"
#import "TBScopeImageAsset.h"
#import "GoogleDriveService.h"

// Operations
#import "UploadImagesOperation.h"
#import "UploadExamsOperation.h"
#import "DownloadExamsOperation.h"
#import "DownloadImagesOperation.h"
#import "UploadLogFileOperation.h"
#import "ScheduleSyncOperation.h"

NSString *const kGoogleDriveSyncErrorDomain = @"GoogleDriveSyncErrorDomain";

//deprecated
static BOOL previousSyncHadNoChanges = NO; //to start, we assume things are NOT in sync
static NSDate* previousSyncDate = nil;

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
    [NSException raise:@"Singleton" format:@"Use +[GoogleDriveSync sharedService]"];
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    
    if (self) {
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.maxConcurrentOperationCount = 1;
        [self.operationQueue addObserver:self
                              forKeyPath:@"operationCount"
                                 options:0
                                 context:NULL];

        // Attach event listeners
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


- (void)handleNetworkChange:(NSNotification *)notice
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

- (BOOL)isOkToSync
{
    int networkStatus = (int)[self.reachability currentReachabilityStatus];
    GoogleDriveService *gdService = [GoogleDriveService sharedService];
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

    // If Google unreachable or sync disabled, abort this operation and call
    // again some time later
    if (!self.syncEnabled || ![self isOkToSync]) {
        NSOperation *op = [[ScheduleSyncOperation alloc] init];
        [self.operationQueue addOperation:op];
        return;
    }

    NSString *message = [NSString stringWithFormat:@"Sync initiated with Google Drive account: %@", [[GoogleDriveService sharedService] userEmail]];
    [TBScopeData CSLog:message inCategory:@"SYNC"];

    // Enqueue jobs to operation queue
    [self _enqueueImageUploads];
//    [self _enqueueExamUploads];
//    [self _enqueueExamDownloads];
//    [self _enqueueImageDownloads];
//    [self _enqueueLogFileUpload];
    [self _enqueueNextSync];
}

- (void)_enqueueImageUploads
{
    NSOperation *op = [[UploadImagesOperation alloc] init];
    [self.operationQueue addOperation:op];
}

- (void)_enqueueExamUploads
{
    NSOperation *op = [[UploadExamsOperation alloc] init];
    [self.operationQueue addOperation:op];
}

- (void)_enqueueExamDownloads
{
    NSOperation *op = [[DownloadExamsOperation alloc] init];
    [self.operationQueue addOperation:op];
}

- (void)_enqueueImageDownloads
{
    NSOperation *op = [[DownloadImagesOperation alloc] init];
    [self.operationQueue addOperation:op];
}

- (void)_enqueueLogFileUpload
{
    UploadLogFileOperation *op = [[UploadLogFileOperation alloc] init];
    [self.operationQueue addOperation:op];
}

- (void)_enqueueNextSync
{
    ScheduleSyncOperation *op = [[ScheduleSyncOperation alloc] init];
    [self.operationQueue addOperation:op];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context
{
    if (object == self.operationQueue && [keyPath isEqualToString:@"operationCount"]) {
        if ([self.operationQueue operationCount] == 0) {
            self.isSyncing = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncUpdate" object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncStopped" object:nil];
            [TBScopeData CSLog:@"Upload/download queues empty or sync disabled" inCategory:@"SYNC"];
        } else if (!self.isSyncing) {
            self.isSyncing = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncUpdate" object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncStarted" object:nil];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GoogleSyncUpdate" object:nil];
        }
    }
}

+ (BOOL)uploadIsEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"UploadEnabled"];
}

+ (BOOL)downloadIsEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DownloadEnabled"];
}

@end
