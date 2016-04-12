//
//  GoogleDriveSync.h
//  TBScope
//
//  Created by Frankie Myers on 1/28/14.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "Reachability.h"

#import "TBScopeHardware.h"
#import "TBScopeData.h"

#import "GTLDrive.h"

#import "CoreDataJSONHelper.h"

#define ONLY_CHECK_RECORDS_SINCE_LAST_FULL_SYNC 0

extern NSString *const kGoogleDriveSyncErrorDomain;
typedef NS_ENUM(int, GoogleDriveSyncError) {
    GoogleDriveSyncError_ExamNotFound
};

@interface GoogleDriveSync : NSObject

+ (id)sharedGDS;

@property (strong, nonatomic) Reachability* reachability;
@property (strong, nonatomic) NSOperationQueue* operationQueue;

@property (nonatomic) BOOL syncEnabled;
@property (nonatomic) BOOL isSyncing;

- (void)doSync;
+ (BOOL)uploadIsEnabled;
+ (BOOL)downloadIsEnabled;

@end
