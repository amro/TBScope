//
//  GoogleDriveService.m
//  TBScope
//
//  Created by Jason Ardell on 11/5/15.
//  Copyright © 2015 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "GoogleDriveService.h"
#import "TBScopeData.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "NSData+MD5.h"
#import "PMKPromise+NoopPromise.h"

static NSString *const kKeychainItemName = @"CellScope";
static NSString *const kClientID = @"822665295778.apps.googleusercontent.com";
static NSString *const kClientSecret = @"mbDjzu2hKDW23QpNJXe_0Ukd";

@implementation GoogleDriveService

@synthesize googleDriveTimeout;

#pragma Initializers

+ (id)sharedService
{
    return [[GoogleDriveService alloc] initPrivate];
//    static GoogleDriveService *sharedService;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        sharedService = [[GoogleDriveService alloc] initPrivate];
//    });
//    return sharedService;
}

// NOTE: Only use this in testing; otherwise use [GoogleDriveService sharedService]
- (instancetype)init
{
    return [[GoogleDriveService alloc] initPrivate];
}

- (instancetype)initPrivate
{
    self = [super init];
    if (self) {
        // Initialize the drive service & load existing credentials from the keychain if available
        self.driveService = [[GTLServiceDrive alloc] init];
        self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                             clientID:kClientID
                                                                                         clientSecret:kClientSecret];
        self.driveService.shouldFetchNextPages = YES;
        self.googleDriveTimeout = 15.0;
    }
    return self;
}

#pragma Status methods

- (BOOL)isLoggedIn
{
    return [self.driveService.authorizer canAuthorize];
}

- (NSString*)userEmail
{
    return [self.driveService.authorizer userEmail];
}

#pragma Queries

- (PMKPromise *)getMetadataForFileId:(NSString *)fileId
{
    if (!fileId) return [PMKPromise noopPromise];

    GTLQueryDrive *query = [GTLQueryDrive queryForFilesGetWithFileId:fileId];
    return [self executeQueryWithTimeout:query];
}

- (PMKPromise *)fileExists:(GTLDriveFile *)file
{
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSString *fileId = [file identifier];
        [self getMetadataForFileId:fileId]
            .then(^(GTLDriveFile *file) { resolve(file); })
            .catch(^(NSError *error) { resolve(nil); });
    }];
}

- (PMKPromise *)getFile:(GTLDriveFile *)file
{
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTMHTTPFetcher *fetcher = [GTMHTTPFetcher fetcherWithURLString:file.downloadUrl];
        
        // For downloads requiring authorization, set the authorizer.
        fetcher.authorizer = self.driveService.authorizer;

        // TODO: check what happens w/o network
        [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
            if (error) {
                resolve(error);
            } else {
                resolve(data);
            }
        }];
    }];
}

- (PMKPromise *)listDirectories
{
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
    query.q = @"mimeType='application/vnd.google-apps.folder' and trashed=false";
    query.maxResults = 100;
    return [self executeQueryWithTimeout:query];
}

- (PMKPromise *)createDirectoryWithTitle:(NSString *)title
{
    if (!title || [title length] < 1) {
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            NSError *error = [NSError errorWithDomain:@"GoogleDriveService"
                                                 code:-1
                                             userInfo:nil];
            resolve(error);
        }];
    }

    GTLDriveFile *folder = [GTLDriveFile object];
    folder.title = title;
    folder.mimeType = @"application/vnd.google-apps.folder";
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:folder
                                                       uploadParameters:nil];
    return [self executeQueryWithTimeout:query];
}

- (PMKPromise *)uploadFile:(GTLDriveFile *)file withData:(NSData *)data
{
    // Check whether file exists
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        [self fileExists:file]
            .then(^(GTLDriveFile *file) { resolve(file); })
            .catch(^{ resolve(nil); });
    }].then(^(GTLDriveFile *existingFile) {
        // Create query
        GTLUploadParameters *uploadParameters = [GTLUploadParameters uploadParametersWithData:data MIMEType:file.mimeType];
        GTLQueryDrive* query;
        if (existingFile) {
            // Check whether file has been modified
            NSString *localMD5 = [data MD5];
            NSString *remoteMD5 = [existingFile md5Checksum];
            if (localMD5 == remoteMD5) {
                // Files have same contents, do not upload
                [TBScopeData CSLog:@"Local file and Google Drive file are the same, not uploading" inCategory:@"SYNC"];
            } else {
                // Files are different, upload
                [TBScopeData CSLog:@"Local file and Google Drive file are different, uploading" inCategory:@"SYNC"];
                query = [GTLQueryDrive queryForFilesUpdateWithObject:file
                                                              fileId:[file identifier]
                                                    uploadParameters:uploadParameters];
            }
        } else {
            // File does not exist on remote server, upload
            [TBScopeData CSLog:@"File does not exist on Google Drive, uploading" inCategory:@"SYNC"];
            query = [GTLQueryDrive queryForFilesInsertWithObject:file
                                                uploadParameters:uploadParameters];
        }

        // Return a no-op promise if we don't have any work to do
        if (!query) return [PMKPromise noopPromise];
        query.setModifiedDate = YES;

        // Execute query
        return [self executeQueryWithTimeout:query];
    });
}

- (PMKPromise *)deleteFileWithId:(NSString *)fileId
{
    return [self getMetadataForFileId:fileId].then(^(GTLDriveFile *existingFile) {
        if (!existingFile) return [PMKPromise noopPromise];

        // Delete the file
        GTLQueryDrive* query = [GTLQueryDrive queryForFilesTrashWithFileId:fileId];
        return [self executeQueryWithTimeout:query];
    });
}

- (PMKPromise *)executeQueryWithTimeout:(GTLQuery *)query
{
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        dispatch_async(dispatch_get_main_queue(), ^{
            GTLServiceTicket* ticket = [self.driveService executeQuery:query
                                                     completionHandler:^(GTLServiceTicket *ticket, id object, NSError *error) {
                                                         if (error) {
                                                             resolve(error);
                                                         } else {
                                                             resolve(object);
                                                         }
                                                     }];

            //since google drive API doesn't call completion or error handler when network connection drops (arg!),
            //set this timer to check the query ticket and make sure it returned something. if not, cancel the query
            //and return an error
            //TODO: roll this into my own executeQuery function and make it universal
            //TODO: check what happens if we are uploading a big file (hopefully returns a diff status code)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.googleDriveTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                //NSLog(@"google returned status code: %ld",(long)ticket.statusCode);
                if (ticket.statusCode==0) { //might also handle other error codes? code of 0 means that it didn't even attempt I guess? the other HTTP codes should get handled in the errorhandler above
                    [ticket cancelTicket];
                    NSError* error = [NSError errorWithDomain:@"GoogleDriveSync" code:123 userInfo:[NSDictionary dictionaryWithObject:@"No response from query. Likely network failure." forKey:@"description"]];
                    resolve(error);
                }
            });
        });
    }];
}

@end
