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
#import "TBScopeImageAsset.h"
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

- (NSArray *)imagesToUpload
{
    // Get a list of all images
    NSOrderedSet *allImages = [self slideImages];

    // Make a dictionary of imageId => MAX(roi.score)
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    for (Images *image in allImages) {
        float maxScore = 0;
        for (ROIs *roi in image.imageAnalysisResults.imageROIs) {
            maxScore = MAX(maxScore, roi.score);
        }
        [dict setObject:[NSNumber numberWithFloat:maxScore]
                 forKey:[image objectID]];
    }

    // Sort list of images by dictionary[imageId]
    NSArray *sortedImages = [allImages sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        float aMaxScore = [[dict objectForKey:[a objectID]] floatValue];
        float bMaxScore = [[dict objectForKey:[b objectID]] floatValue];

        // Sort descending
        if (aMaxScore > bMaxScore) {
            return (NSComparisonResult)NSOrderedAscending;
        } else if (aMaxScore < bMaxScore) {
            return (NSComparisonResult)NSOrderedDescending;
        } else {
            return (NSComparisonResult)NSOrderedSame;
        }
    }];

    // Get MaxUploadsPerSlide value
    NSInteger maxUploadsPerSlide = [[NSUserDefaults standardUserDefaults] integerForKey:@"MaxUploadsPerSlide"];
    if (!maxUploadsPerSlide) maxUploadsPerSlide = 10;

    // Slice list of images based on MaxUploadsPerSlide
    NSRange range;
    range.location = 0;
    range.length = MIN([sortedImages count], maxUploadsPerSlide);
    NSArray *results = [sortedImages subarrayWithRange:range];

    // Return it
    return results;
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
                [TBScopeImageAsset getImageAtPath:self.roiSpritePath]
                    .then(^(NSData *data) { resolve(data); })
                    .catch(^(NSError *error) { resolve(error); });
            }];
        }];
    }).then(^(UIImage *image) {
        // Do nothing if local file is same as remote
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            NSData *localData = UIImageJPEGRepresentation((UIImage *)image, 1.0);
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
            [TBScopeImageAsset saveImage:[UIImage imageWithData:data]]
                .then(^(NSURL *url) { resolve([url absoluteString]); })
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

@end
