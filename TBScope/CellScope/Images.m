//
//  Images.m
//  TBScope
//
//  Created by Frankie Myers on 2/18/14.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "Images.h"
#import <UIKit/UIKit.h>
#import "ImageAnalysisResults.h"
#import "TBScopeData.h"
#import "Slides.h"
#import "TBScopeImageAsset.h"
#import "GoogleDriveService.h"
#import "PMKPromise+NoopPromise.h"
#import "PMKPromise+RejectedPromise.h"
#import "Exams.h"

@implementation Images

@dynamic fieldNumber;
@dynamic metadata;
@dynamic imageContentMetrics;
@dynamic imageFocusMetrics;
@dynamic path;
@dynamic googleDriveFileID;
@dynamic imageAnalysisResults;
@dynamic slide;
@dynamic xCoordinate;
@dynamic yCoordinate;
@dynamic zCoordinate;
@dynamic focusAttempts;
@dynamic focusResult;

- (PMKPromise *)uploadToGoogleDrive:(GoogleDriveService *)googleDriveService
{
    __weak typeof(self) weakSelf = self;
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            [[strongSelf managedObjectContext] performBlock:^{
                NSString *message = [NSString stringWithFormat:@"Uploading image #%d from slide #%d from exam %@ with googleDriveFileID %@",
                                     strongSelf.fieldNumber,
                                     strongSelf.slide.slideNumber,
                                     strongSelf.slide.exam.examID,
                                     strongSelf.googleDriveFileID
                                     ];
                [TBScopeData CSLog:message inCategory:@"SYNC"];
                
                NSString *fileID = strongSelf.googleDriveFileID;
                resolve(fileID);
            }];
        }
    }].then(^(NSString *googleDriveFileID) {
        if (googleDriveFileID) {
            [TBScopeData CSLog:@"Not uploading because image is already on Google Drive" inCategory:@"SYNC"];
            return [PMKPromise noopPromise];
        }

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                [[strongSelf managedObjectContext] performBlock:^{
                [TBScopeImageAsset getImageAtPath:[self path]]
                    .then(^(UIImage *image) { resolve(image); })
                    .catch(^(NSError *error) { resolve(error); });
                }];
            }
        }];
    }).then(^ PMKPromise* (UIImage *image) {
        if (!image) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                [[strongSelf managedObjectContext] performBlock:^{
                    NSString *message = [NSString stringWithFormat:@"Could not load image from path %@", strongSelf.path];
                    [TBScopeData CSLog:message inCategory:@"SYNC"];
                }];
            }
            return [PMKPromise noopPromise];
        }

        // Upload the file
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                [[strongSelf managedObjectContext] performBlock:^{
                    // Create a google file object from this image
                    GTLDriveFile *file = [GTLDriveFile object];
                    file.title = [NSString stringWithFormat:@"%@ - %@ - %d-%d.jpg",
                                  strongSelf.slide.exam.cellscopeID,
                                  strongSelf.slide.exam.examID,
                                  strongSelf.slide.slideNumber,
                                  strongSelf.fieldNumber];
                    file.descriptionProperty = @"Uploaded from CellScope";
                    file.mimeType = @"image/jpeg";
                    file.modifiedDate = [GTLDateTime dateTimeWithRFC3339String:strongSelf.slide.exam.dateModified];

                    // Set parent folder if necessary
                    NSString *remoteDirIdentifier = [[NSUserDefaults standardUserDefaults] valueForKey:@"RemoteDirectoryIdentifier"];
                    if (remoteDirIdentifier) {
                        GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
                        parentRef.identifier = remoteDirIdentifier;
                        file.parents = @[ parentRef ];
                    }

                    NSData *data = UIImageJPEGRepresentation((UIImage *)image, 1.0);

                    NSString *message = [NSString stringWithFormat:@"Uploading local file from path %@ to Google Drive with title %@",
                        strongSelf.path,
                        file.title
                    ];
                    [TBScopeData CSLog:message inCategory:@"SYNC"];

                    [googleDriveService uploadFile:file withData:data]
                        .then(^(GTLDriveFile *file) { resolve(file); })
                        .catch(^(NSError *error) { resolve(error); });
                }];
            }
        }];
    }).then(^ PMKPromise* (GTLDriveFile *file) {
        if (!file) {
            [TBScopeData CSLog:@"No file was returned from Google Drive" inCategory:@"SYNC"];
            return [PMKPromise noopPromise];
        }

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            if (file) {
                __strong typeof(self) strongSelf = weakSelf;
                if (strongSelf) {
                    [[strongSelf managedObjectContext] performBlock:^{
                        strongSelf.googleDriveFileID = file.identifier;
                        resolve(nil);
                    }];
                }
            } else {
                NSError *error = [NSError errorWithDomain:@"Images" code:0 userInfo:nil];
                resolve(error);
            }
        }];
    });
}

- (PMKPromise *)downloadFromGoogleDrive:(GoogleDriveService *)googleDriveService
{
    __block NSManagedObjectContext *moc = [self managedObjectContext];
    if (!moc) {
        dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            moc.parentContext = [[TBScopeData sharedData] managedObjectContext];
        });
    }

    __weak typeof(self) weakSelf = self;
    
    __block NSString *path;
    __block NSString *googleDriveFileID;
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        __strong typeof(self) strongSelf = weakSelf;
        if (strongSelf) {
            [moc performBlock:^{
                Images *localImage = [moc objectWithID:strongSelf.objectID];
                path = localImage.path;
                googleDriveFileID = localImage.googleDriveFileID;
                resolve(nil);
            }];
        }
    }].then(^{
        if (!googleDriveFileID) return [PMKPromise noopPromise];
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [googleDriveService getMetadataForFileId:googleDriveFileID]
                .then(^(GTLDriveFile *remoteFile) { resolve(remoteFile); })
                .catch(^(NSError *error) { resolve(error); });
        }];
    }).then(^(GTLDriveFile *remoteFile) {
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            if (!path) {
                resolve(remoteFile);
                return;
            }

            [TBScopeImageAsset getImageAtPath:path]
                .then(^(UIImage *image) {
                    if (image) {
                        resolve(nil);  // do nothing
                    } else {
                        resolve(remoteFile);  // keep downloading
                    }
                })
                .catch(^(NSError *error) {
                    resolve(remoteFile);  // no file found, keep downloading
                });
        }];
    }).then(^ PMKPromise* (GTLDriveFile *file) {
        if (!file) return [PMKPromise noopPromise];

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [googleDriveService getFile:file]
                .then(^(NSData *data) { resolve(data); })
                .catch(^(NSError *error) { resolve(error); });
        }];
    }).then(^ PMKPromise* (NSData *data) {
        if (!data) return [PMKPromise noopPromise];

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            // Save this image to asset library as jpg
            UIImage* im = [UIImage imageWithData:data];
            [TBScopeImageAsset saveImage:im]
                .then(^(NSURL *url) { resolve([url absoluteString]); })
                .catch(^(NSError *error) { resolve(error); });
        }];
    }).then(^ PMKPromise* (NSString *path) {
        if (!path) return [PMKPromise noopPromise];

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            __strong typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                [moc performBlock:^{
                    Images *localImage = [moc objectWithID:strongSelf.objectID];
                    localImage.path = path;
                    resolve(localImage);
                }];
            }
        }];
    });
}

@end
