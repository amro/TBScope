//
//  Slides.m
//  TBScope
//
//  Created by Frankie Myers on 2/18/14.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "Slides.h"
#import "Exams.h"
#import "Images.h"
#import "SlideAnalysisResults.h"
#import "TBScopeData.h"
#import <ImageManager/IMGImage.h>
#import <ImageManager/IMGDocumentsDirectory.h>
#import "NSData+MD5.h"
#import "PMKPromise+NoopPromise.h"

@implementation Slides

@dynamic slideNumber;
@dynamic sputumQuality;
@dynamic dateCollected;
@dynamic dateScanned;
@dynamic roiSpritePath;
@dynamic roiSpriteGoogleDriveFileID;
@dynamic slideAnalysisResults;
@dynamic slideImages;
@dynamic numSkippedBorderFields;
@dynamic numSkippedEmptyFields;
@dynamic exam;

- (void)addSlideImagesObject:(Images *)value {
    NSMutableOrderedSet* tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.slideImages];
    [tempSet addObject:value];
    self.slideImages = tempSet;
}

- (BOOL)allImagesAreLocal
{
    // If we don't have any images return true
    if ([self.slideImages count] <= 0) return YES;

    // Otherwise check each for empty path
    for (Images *image in self.slideImages) {
        if (!image.path) return NO;
    }
    return YES;
}

- (BOOL)hasLocalImages
{
    // If we don't have any images return true
    if ([self.slideImages count] <= 0) return NO;

    // Otherwise check each for empty path
    for (Images *image in self.slideImages) {
        if (image.path) return YES;
    }
    return NO;
}

- (PMKPromise *)uploadRoiSpriteSheetToGoogleDrive:(GoogleDriveService *)googleDriveService
{
    __block NSString *remoteMd5;
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        [self.managedObjectContext performBlock:^{
            resolve(self.roiSpritePath);
        }];
    }].then(^(NSString *roiSpritePath) {
        if (!roiSpritePath) return [PMKPromise noopPromise];

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [self.managedObjectContext performBlock:^{
                // Fetch metadata
                [googleDriveService getMetadataForFileId:self.roiSpriteGoogleDriveFileID]
                    .then(^(GTLDriveFile *file) { resolve(file); })
                    .catch(^(NSError *error) { resolve(error); });
            }];
        }];
    }).then(^(GTLDriveFile *existingRemoteFile) {
        if (!existingRemoteFile) return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [self.managedObjectContext performBlock:^{
                resolve(self.roiSpritePath);
            }];
        }];

        // Assign remote md5 for later use
        remoteMd5 = [existingRemoteFile md5Checksum];

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [self.managedObjectContext performBlock:^{
                // Do nothing if local file is not newer than remote
                NSDate *localTime = [TBScopeData dateFromString:self.exam.dateModified];
                NSDate *remoteTime = existingRemoteFile.modifiedDate.date;
                if ([remoteTime timeIntervalSinceDate:localTime] > 0) {
                    resolve(nil);
                } else {
                    resolve(self.roiSpritePath);
                }
            }];
        }];
    }).then(^(NSString *localPath) {
        if (!localPath) return [PMKPromise noopPromise];

        // Fetch data from the filesystem
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [self.managedObjectContext performBlock:^{
                [IMGImage loadDataForURI:self.roiSpritePath]
                    .then(^(NSData *data) { resolve(data); })
                    .catch(^(NSError *error) { resolve(error); });
            }];
        }];
    }).then(^(NSData *localData) {
        // Do nothing if local file is same as remote
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            NSString *localMd5 = [localData MD5];
            if ([localMd5 isEqualToString:remoteMd5]) {
                resolve(nil);
            } else {
                resolve(localData);
            }
        }];
    }).then(^(NSData *data) {
        if (!data) return [PMKPromise noopPromise];

        // Upload the file
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [self.managedObjectContext performBlock:^{
                GTLDriveFile *file = [GTLDriveFile object];
                file.title = [NSString stringWithFormat:@"%@ - %@ - %d rois.jpg",
                              self.exam.cellscopeID,
                              self.exam.examID,
                              self.slideNumber];
                file.descriptionProperty = @"Uploaded from CellScope";
                file.mimeType = @"image/jpeg";
                file.modifiedDate = [GTLDateTime dateTimeWithRFC3339String:self.exam.dateModified];

                // Set parent folder if necessary
                NSString *remoteDirIdentifier = [[NSUserDefaults standardUserDefaults] valueForKey:@"RemoteDirectoryIdentifier"];
                if (remoteDirIdentifier) {
                    GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
                    parentRef.identifier = remoteDirIdentifier;
                    file.parents = @[ parentRef ];
                }

                [googleDriveService uploadFile:file withData:data]
                    .then(^(GTLDriveFile *file) { resolve(file); })
                    .catch(^(NSError *error) { resolve(error); });
            }];
        }];
    }).then(^(GTLDriveFile *remoteFile) {
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            if (remoteFile) {
                [self.managedObjectContext performBlock:^{
                    self.roiSpriteGoogleDriveFileID = remoteFile.identifier;
                    resolve(self);
                }];
            } else {
                resolve(nil);
            }
        }];
    });
}

- (PMKPromise *)downloadRoiSpriteSheetFromGoogleDrive:(GoogleDriveService *)googleDriveService
{
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        [self.managedObjectContext performBlock:^{
            if (self.roiSpriteGoogleDriveFileID) {
                resolve(self.roiSpriteGoogleDriveFileID);
            } else {
                resolve(nil);
            }
        }];
    }].then(^(NSString *roiSpriteGoogleDriveFileID) {
        if (!roiSpriteGoogleDriveFileID) return [PMKPromise noopPromise];

        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            // Get metadata for existing roiSpriteSheet
            [googleDriveService getMetadataForFileId:roiSpriteGoogleDriveFileID]
                .then(^(GTLDriveFile *file) { resolve(file); })
                .catch(^(NSError *error) { resolve(error); });
        }];
    }).then(^(GTLDriveFile *existingRemoteFile) {
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [self.managedObjectContext performBlock:^{
                // Do nothing if remote file is not newer than remote
                NSDate *localTime = [TBScopeData dateFromString:self.exam.dateModified];
                NSDate *remoteTime = existingRemoteFile.modifiedDate.date;
                if ([localTime timeIntervalSinceDate:remoteTime] > 0) {
                    resolve(nil);
                } else {
                    resolve(existingRemoteFile);
                }
            }];
        }];
    }).then(^(GTLDriveFile *existingRemoteFile) {
        if (!existingRemoteFile) return [PMKPromise noopPromise];

        // Download the file
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [googleDriveService getFile:existingRemoteFile]
                .then(^(NSData *data) { resolve(data); })
                .catch(^(NSError *error) { resolve(error); });
        }];
    }).then(^(NSData *data) {
        // Save to file
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            NSString *uri = [[self class] generateURI];
            [IMGImage saveData:data toURI:uri]
                .then(^(NSString *url) { resolve(url); })
                .catch(^(NSError *error) { resolve(error); });
        }];
    }).then(^(NSString *localFilePath) {
        // Update roiSpritePath
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            [self.managedObjectContext performBlock:^{
                self.roiSpritePath = localFilePath;
                resolve(nil);
            }];
        }];
    });
}

+ (NSString *)generateURI
{
    NSString *localURI;
    while (!localURI || [IMGDocumentsDirectory fileExistsAtURI:localURI]) {
        NSString *randomString = [[self class] _randomStringOfLength:32];
        NSString *localPath = [NSString stringWithFormat:@"roi-sprites/%@.png", randomString];
        localURI = [IMGDocumentsDirectory uriFromPath:localPath];
    }
    return localURI;
}

- (PMKPromise *)loadUIImageForRoiSpritePath
{
    return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        [self.managedObjectContext performBlock:^{
            resolve(self.roiSpritePath);
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
