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
#import <ImageManager/IMGImage.h>
#import <ImageManager/IMGDocumentsDirectory.h>
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
    __block NSManagedObjectContext *moc = [self managedObjectContext];
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        [moc performBlock:^{
            resolve(self.googleDriveFileID);
        }];
    }].then(^(NSString *googleDriveFileID) {
        if (googleDriveFileID) return [PMKPromise noopPromise];

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [self loadUIImageForPath]
                .then(^(UIImage *image) { resolve(image); })
                .catch(^(NSError *error) { resolve(error); });
        }];
    }).then(^ PMKPromise* (UIImage *image) {
        if (!image) return [PMKPromise noopPromise];

        // Upload the file
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [moc performBlock:^{
                // Create a google file object from this image
                GTLDriveFile *file = [GTLDriveFile object];
                file.title = [NSString stringWithFormat:@"%@ - %@ - %d-%d.jpg",
                              self.slide.exam.cellscopeID,
                              self.slide.exam.examID,
                              self.slide.slideNumber,
                              self.fieldNumber];
                file.descriptionProperty = @"Uploaded from CellScope";
                file.mimeType = @"image/jpeg";
                file.modifiedDate = [GTLDateTime dateTimeWithRFC3339String:self.slide.exam.dateModified];

                // Set parent folder if necessary
                NSString *remoteDirIdentifier = [[NSUserDefaults standardUserDefaults] valueForKey:@"RemoteDirectoryIdentifier"];
                if (remoteDirIdentifier) {
                    GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
                    parentRef.identifier = remoteDirIdentifier;
                    file.parents = @[ parentRef ];
                }

                NSData *data = UIImageJPEGRepresentation((UIImage *)image, 1.0);

                [googleDriveService uploadFile:file withData:data]
                    .then(^(GTLDriveFile *file) { resolve(file); })
                    .catch(^(NSError *error) { resolve(error); });
            }];
        }];
    }).then(^ PMKPromise* (GTLDriveFile *file) {
        if (!file) return [PMKPromise noopPromise];

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            if (file) {
                [moc performBlock:^{
                    self.googleDriveFileID = file.identifier;
                    resolve(nil);
                }];
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

    __block NSString *path;
    __block NSString *googleDriveFileID;
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        [moc performBlock:^{
            Images *localImage = [moc objectWithID:self.objectID];
            path = localImage.path;
            googleDriveFileID = localImage.googleDriveFileID;
            resolve(nil);
        }];
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

            [self loadUIImageForPath]
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
            // Save this image to documents directory as jpg
            NSString *uri = [[self class] generateURI];
            [IMGImage saveData:data toURI:uri]
                .then(^(NSString *url) { resolve(url); })
                .catch(^(NSError *error) { resolve(error); });
        }];
    }).then(^ PMKPromise* (NSString *path) {
        if (!path) return [PMKPromise noopPromise];

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [moc performBlock:^{
                Images *localImage = [moc objectWithID:self.objectID];
                localImage.path = path;
                resolve(localImage);
            }];
        }];
    });
}

+ (NSString *)generateURI
{
    NSString *localURI;
    while (!localURI || [IMGDocumentsDirectory fileExistsAtURI:localURI]) {
        NSString *randomString = [[self class] _randomStringOfLength:32];
        NSString *localPath = [NSString stringWithFormat:@"images/%@.jpg", randomString];
        localURI = [IMGDocumentsDirectory uriFromPath:localPath];
    }
    return localURI;
}

- (PMKPromise *)loadUIImageForPath
{
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        [self.managedObjectContext performBlock:^{
            resolve(self.path);
        }];
    }].then(^(NSString *uri) {
        if (!uri) return [PMKPromise noopPromise];
        return [IMGImage loadDataForURI:uri];
    }).then(^(NSData *data) {
        if (!data) return [PMKPromise noopPromise];
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            UIImage *imageFromData = [UIImage imageWithData:data];
            UIImage *orientedImage = [[UIImage alloc] initWithCGImage:imageFromData.CGImage
                                                                scale:1.0
                                                          orientation:UIImageOrientationUp];
            resolve(orientedImage);
        }];
    });
}

#pragma Private methods

+ (NSString *)_randomStringOfLength:(int)length
{
    NSString *alphabet  = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY0123456789";
    NSMutableString *s = [NSMutableString stringWithCapacity:20];
    for (int i = 0; i < length; i++) {
        u_int32_t r = arc4random() % [alphabet length];
        unichar c = [alphabet characterAtIndex:r];
        [s appendFormat:@"%C", c];
    }
    return s;
}

@end
