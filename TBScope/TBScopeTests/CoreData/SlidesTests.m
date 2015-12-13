//
//  SlidesTests.m
//  TBScope
//
//  Created by Jason Ardell on 11/12/15.
//  Copyright © 2015 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "Slides.h"
#import "TBScopeData.h"
#import "GoogleDriveService.h"
#import "CoreDataJSONHelper.h"
#import <ImageManager/IMGImage.h>
#import <ImageManager/IMGDocumentsDirectory.h>
#import "NSData+MD5.h"
#import "PMKPromise+NoopPromise.h"
#import "PMKPromise+RejectedPromise.h"

@interface SlidesTests : XCTestCase
@property (strong, nonatomic) Slides *slide;
@property (strong, nonatomic) NSManagedObjectContext *moc;
@property (strong, nonatomic) GoogleDriveService *googleDriveService;
@end

@implementation SlidesTests

- (void)setUp
{
    [super setUp];
    
    // Set up the managedObjectContext
    self.moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.moc.parentContext = [[TBScopeData sharedData] managedObjectContext];

    // Inject GoogleDriveService
    GoogleDriveService *mockGds = OCMPartialMock([[GoogleDriveService alloc] init]);
    self.googleDriveService = mockGds;

    [self.moc performBlockAndWait:^{
        // Create a slide
        self.slide = (Slides*)[NSEntityDescription insertNewObjectForEntityForName:@"Slides" inManagedObjectContext:self.moc];
        self.slide.exam = (Exams*)[NSEntityDescription insertNewObjectForEntityForName:@"Exams" inManagedObjectContext:self.moc];
    }];
}

- (void)tearDown
{
    self.moc = nil;
}

- (void)setSlideRoiSpritePath
{
    [self.moc performBlockAndWait:^{
        self.slide.roiSpritePath = @"test-file-id";
    }];
}

- (void)setSlideRoiSpriteGoogleDriveFileID
{
    [self.moc performBlockAndWait:^{
        self.slide.roiSpriteGoogleDriveFileID = @"test-file-id";
    }];
}

- (void)stubOutRemoteFileTime:(NSString *)remoteTime md5:(NSString *)md5
{
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *remoteFile = [[GTLDriveFile alloc] init];
        
        // Stub out remote file time to newer than local modification time
        remoteFile.modifiedDate = [GTLDateTime dateTimeWithRFC3339String:remoteTime];
        
        // Stub out remote md5 to be different from local
        remoteFile.md5Checksum = md5;
        
        resolve(remoteFile);
    }];
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn(promise);
}

- (void)stubOutFetchingImageToSucceed
{
    id mock = [OCMockObject mockForClass:[IMGImage class]];
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSString *imageName = @"fl_01_01";
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        NSData *data = UIImageJPEGRepresentation(image, 1.0);
        resolve(data);
    }];
    [[[mock stub] andReturn:promise] loadDataForURI:[OCMArg any]];
}

#pragma allImagesAreLocal tests

- (void)testThatAllImagesAreLocalReturnsTrueIfThereAreNoImages
{
    [self.moc performBlockAndWait:^{
        XCTAssertTrue([self.slide allImagesAreLocal]);
    }];
}

- (void)testThatAllImagesAreLocalReturnsTrueIfAllImagesAreLocal
{
    // Add an image with a local path
    [self.moc performBlockAndWait:^{
        Images *image = [NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        image.path = @"assets-library://path/to/image.jpg";
        [self.slide addSlideImagesObject:image];
        XCTAssertTrue([self.slide allImagesAreLocal]);
    }];
}

- (void)testThatAllImagesAreLocalReturnsTrueIfASingleImageIsNotLocal
{
    // Add an image without a local path
    [self.moc performBlockAndWait:^{
        Images *image = [NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        image.path = nil;
        [self.slide addSlideImagesObject:image];
        XCTAssertFalse([self.slide allImagesAreLocal]);
    }];
}

#pragma hasLocalImages tests

- (void)testThatHasLocalImagesReturnsFalseIfSlideHasNoImages
{
    [self.moc performBlockAndWait:^{
        XCTAssertFalse([self.slide hasLocalImages]);
    }];
}

- (void)testThatHasLocalImagesReturnsFalseIfSlideHasOnlyRemoteImages
{
    // Add an image with only a remote path
    [self.moc performBlockAndWait:^{
        Images *image = [NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        image.googleDriveFileID = @"remote-id";
        image.path = nil;
        [self.slide addSlideImagesObject:image];
        XCTAssertFalse([self.slide hasLocalImages]);
    }];
}

- (void)testThatHasLocalImagesReturnsFalseIfSlideHasASingleLocalImage
{
    // Add an image with only a remote path
    [self.moc performBlockAndWait:^{
        Images *image = [NSEntityDescription insertNewObjectForEntityForName:@"Images" inManagedObjectContext:self.moc];
        image.googleDriveFileID = @"remote-id";
        image.path = @"assets-library://path/to/image.jpg";
        [self.slide addSlideImagesObject:image];
        XCTAssertTrue([self.slide hasLocalImages]);
    }];
}

#pragma uploadToGoogleDrive tests

- (void)testThatUploadRoiSpriteSheetToGoogleDriveDoesNotUploadIfPathIsNil
{
    [self.moc performBlockAndWait:^{
        self.slide.roiSpritePath = nil;
    }];

    // Stub out [GoogleDriveService uploadFile:withData:] to fail
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect uploadFile:withData: to be called");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) { [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadRoiSpriteSheetToGoogleDriveUploadsIfGetMetadataForFileIdReturnsNil
{
    [self setSlideRoiSpritePath];

    // Stub out getMetadataForFileId to return nil
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out fetching image to succeed
    [self stubOutFetchingImageToSucceed];

    // Stub out [GoogleDriveService uploadFile:withData:] to succeed
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) { [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadRoiSpriteSheetToGoogleDriveSetsParentDirectory
{
    [self setSlideRoiSpritePath];

    // Set parent directory identifier in NSUserDefaults
    NSString *remoteDirIdentifier = @"remote-directory-identifier";
    id userDefaultsMock = OCMClassMock([NSUserDefaults class]);
    OCMStub([userDefaultsMock valueForKey:@"RemoteDirectoryIdentifier"])
        .andReturn(remoteDirIdentifier);
    OCMStub([userDefaultsMock standardUserDefaults])
        .andReturn(userDefaultsMock);

    // Stub out getMetadataForFileId to return nil
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out fetching image to succeed
    [self stubOutFetchingImageToSucceed];

    // Stub out [GoogleDriveService uploadFile:withData:] to succeed
    GTLDriveFile *fileArg = [OCMArg checkWithBlock:^BOOL(GTLDriveFile *file) {
        GTLDriveFile *actualRemoteDir = [file.parents objectAtIndex:0];
        return [actualRemoteDir.identifier isEqualToString:remoteDirIdentifier];
    }];
    OCMStub([self.googleDriveService uploadFile:fileArg
                                             withData:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) {
            [expectation fulfill];
            [userDefaultsMock stopMocking];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadRoiSpriteSheetToGoogleDriveDoesNotSetParentsWhenRemoteDirectoryIdentifierIsNil
{
    [self setSlideRoiSpritePath];

    // Set parent directory identifier in NSUserDefaults
    id userDefaultsMock = OCMClassMock([NSUserDefaults class]);
    OCMStub([userDefaultsMock valueForKey:@"RemoteDirectoryIdentifier"])
        .andReturn(nil);
    OCMStub([userDefaultsMock standardUserDefaults])
        .andReturn(userDefaultsMock);

    // Stub out getMetadataForFileId to return nil
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out fetching image to succeed
    [self stubOutFetchingImageToSucceed];

    // Stub out [GoogleDriveService uploadFile:withData:] to succeed
    GTLDriveFile *fileArg = [OCMArg checkWithBlock:^BOOL(GTLDriveFile *file) {
        return (file.parents == nil);
    }];
    OCMStub([self.googleDriveService uploadFile:fileArg
                                             withData:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) {
            [expectation fulfill];
            [userDefaultsMock stopMocking];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadRoiSpriteSheetToGoogleDriveDoesNotUploadIfRemoteFileIsNewerThanLocalFile
{
    [self setSlideRoiSpritePath];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2014-11-10T12:00:00.00Z";
    }];

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2015-11-10T12:00:00.00Z" md5:md5];

    // Stub out fetching image to succeed
    [self stubOutFetchingImageToSucceed];

    // Stub out [GoogleDriveService uploadFile:withData:] to fail
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect uploadFile:withData: to be called");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) { [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadRoiSpriteSheetToGoogleDriveDoesNotUploadIfRemoteFileHasSameMd5AsLocalFile
{
    [self setSlideRoiSpritePath];

    // Stub out local metadata
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];
    
    // Stub out fetching image to succeed
    [self stubOutFetchingImageToSucceed];

    // Stub out [GoogleDriveService uploadFile:withData:] to fail
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect uploadFile:withData: to be called");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Get local image at path
    [IMGImage loadDataForURI:@"some-path"]
        .then(^(NSData *data) {
            // Calculate md5 of local file
            NSString *localMd5 = [data MD5];

            // Stub remote metadata
            [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:localMd5];

            // Call uploadToGoogleDrive
            [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
                .then(^(GTLDriveFile *file) { [expectation fulfill]; })
                .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });
        });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadToGoogleDriveUploadsROISpriteSheet
{
    [self setSlideRoiSpritePath];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];

    // Stub out fetching image to succeed
    [self stubOutFetchingImageToSucceed];

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Stub out [GoogleDriveService uploadFile:withData:] to succeed
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) { [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadToGoogleDriveRejectsPromiseIfROISpriteSheetUploadFails
{
    [self setSlideRoiSpritePath];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];

    // Stub out fetching image to succeed
    [self stubOutFetchingImageToSucceed];

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Stub out [GoogleDriveService uploadFile:withData:] to fail
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andReturn([PMKPromise rejectedPromise]);

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^(NSError *error) { XCTFail(@"Expected promise to reject"); })
        .catch(^(GTLDriveFile *file) { [expectation fulfill]; });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatUploadToGoogleDriveUpdatesROISpriteSheetGoogleDriveIdAfterUploading
{
    [self setSlideRoiSpritePath];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Stub out remote file time to be newer
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];

    // Stub out fetching image to succeed
    [self stubOutFetchingImageToSucceed];

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    
    // Stub out [GoogleDriveService uploadFile:withData:] to fail
    NSString *remoteFileId = @"some-file-id";
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = [[GTLDriveFile alloc] init];
        file.identifier = remoteFileId;
        resolve(file);
    }];
    OCMStub([self.googleDriveService uploadFile:[OCMArg any] withData:[OCMArg any]])
        .andReturn(promise);

    // Call uploadToGoogleDrive
    [self.slide uploadRoiSpriteSheetToGoogleDrive:self.googleDriveService]
        .then(^{
            [self.moc performBlock:^{
                NSString *localFileId = self.slide.roiSpriteGoogleDriveFileID;
                XCTAssert([localFileId isEqualToString:remoteFileId]);
                [expectation fulfill];
            }];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

#pragma downloadFromGoogleDrive tests

- (void)testThatDownloadFromGoogleDriveDoesNotDownloadIfRoiSpriteGoogleDriveIdIsNil
{
    [self.moc performBlockAndWait:^{
        self.slide.roiSpriteGoogleDriveFileID = nil;
    }];
    
    // Stub out [GoogleDriveService getFile:] to fail
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect downloadFileWithId to be called");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call download
    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^{ [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveDoesNotDownloadIfGetMetadataForFileIdReturnsNil
{
    // Stub out [googleDriveService getMetadataForFileId] to return nil
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Fail if getFile is called
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect [googleDriveService getFile] to be called.");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^{ [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve."); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveDoesNotDownloadIfLocalFileIsNewerThanRemoteFile
{
    // Stub out file times and md5s
    NSString *md5 = @"abc123";
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:md5];
    [self.moc performBlockAndWait:^{
        self.slide.exam.dateModified = @"2015-11-10T12:00:00.00Z";
    }];

    // Fail if getFile is called
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect [googleDriveService getFile] to be called.");
        });

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^{ [expectation fulfill]; })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve."); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveFetchesSpriteSheetFromServer
{
    [self setSlideRoiSpriteGoogleDriveFileID];

    // Stub out getMetadataForFile to return a file
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = [[GTLDriveFile alloc] init];
        resolve(file);
    }];
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn(promise);

    // Stub out getFile to return NSData
    PMKPromise *getFilePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSData *data = [@"hello world" dataUsingEncoding:NSUTF8StringEncoding];
        resolve(data);
    }];
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andReturn(getFilePromise);

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    
    // Call download
    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) {
            OCMVerify([self.googleDriveService getFile:[OCMArg any]]);
            [expectation fulfill];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveSavesFileToAssetLibrary
{
    [self setSlideRoiSpriteGoogleDriveFileID];

    // Stub out getMetadataForFile to return a file
    PMKPromise *getMetadataPromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = [[GTLDriveFile alloc] init];
        resolve(file);
    }];
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn(getMetadataPromise);

    // Stub out getFile to return NSData
    PMKPromise *getFilePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSData *data = [@"hello world" dataUsingEncoding:NSUTF8StringEncoding];
        resolve(data);
    }];
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andReturn(getFilePromise);

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    
    // Stub out saveImage
    id saveImageMock = [OCMockObject mockForClass:[IMGImage class]];

    // Call download
    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^{
            OCMVerify([saveImageMock saveData:[OCMArg any] toURI:[OCMArg any]]);
            [expectation fulfill];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveUpdatesRoiSpriteSheetPathAfterDownloading
{
    [self setSlideRoiSpriteGoogleDriveFileID];

    // Stub out getMetadataForFile to return a file
    PMKPromise *getMetadataPromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = [[GTLDriveFile alloc] init];
        resolve(file);
    }];
    OCMStub([self.googleDriveService getMetadataForFileId:[OCMArg any]])
        .andReturn(getMetadataPromise);

    // Stub out getFile to return NSData
    PMKPromise *getFilePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSString *imageName = @"fl_01_01";
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        NSData *data = UIImageJPEGRepresentation(image, 1.0);
        resolve(data);
    }];
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andReturn(getFilePromise);

    // Stub out saving image to return a given uri
    id mock = [OCMockObject mockForClass:[IMGImage class]];
    NSString *uri = @"assets-library://path/to/image.jpg";
    PMKPromise *saveImagePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        resolve(uri);
    }];
    [[[mock stub] andReturn:saveImagePromise] saveData:[OCMArg any]
                                                 toURI:[OCMArg any]];

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    
    // Call download
    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) {
            [self.moc performBlock:^{
                // Verify that slide.roiSpritePath was set
                XCTAssert([self.slide.roiSpritePath isEqualToString:uri]);
                [expectation fulfill];
            }];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatDownloadFromGoogleDriveReplacesExistingROISpriteSheetWithNewerOneFromServer
{
    // Set up existing local file
    [self setSlideRoiSpritePath];

    // Set up existing remote file
    [self setSlideRoiSpriteGoogleDriveFileID];
    [self stubOutRemoteFileTime:@"2014-11-10T12:00:00.00Z" md5:@"abc123"];

    // Stub out getFile to return NSData
    PMKPromise *getFilePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSString *imageName = @"fl_01_01";
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        NSData *data = UIImageJPEGRepresentation(image, 1.0);
        resolve(data);
    }];
    OCMStub([self.googleDriveService getFile:[OCMArg any]])
        .andReturn(getFilePromise);

    // Stub out saving image to return a given path
    NSString *uri = @"assets-library://path/to/image.jpg";
    PMKPromise *saveImagePromise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        resolve(uri);
    }];
    id mock = [OCMockObject mockForClass:[IMGImage class]];
    [[[mock stub] andReturn:saveImagePromise] saveData:[OCMArg any]
                                                 toURI:[OCMArg any]];

    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    
    // Call download
    [self.slide downloadRoiSpriteSheetFromGoogleDrive:self.googleDriveService]
        .then(^(GTLDriveFile *file) {
            [self.moc performBlock:^{
                // Verify that slide.roiSpritePath was set
                XCTAssert([self.slide.roiSpritePath isEqualToString:uri]);
                [expectation fulfill];
            }];
        })
        .catch(^(NSError *error) { XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

#pragma loadUIImageForRoiSpritePath tests

- (void)testThatLoadUIImageForRoiSpritePathResolvesIfImageExistsAtPath
{
    // Set fake image path
    NSString *uri = [IMGDocumentsDirectory uriFromPath:@"path/to/image.jpg"];
    [self.slide.managedObjectContext performBlockAndWait:^{
        self.slide.roiSpritePath = uri;
    }];

    // Stub out [IMGDocumentsDirectory loadDataForURI] to resolve with data
    id mock = [OCMockObject mockForClass:[IMGImage class]];
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSString *imageName = @"fl_01_01";
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        NSData *data = UIImageJPEGRepresentation(image, 1.0);
        resolve(data);
    }];
    [[[mock stub] andReturn:promise] loadDataForURI:[OCMArg any]];

    // Get UIImage
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    [self.slide loadUIImageForRoiSpritePath]
        .then(^(UIImage *uiImage) {
            XCTAssertNotNil(uiImage);
            [expectation fulfill];
        })
        .catch(^(NSError *error) {
            XCTFail(@"Expected promise to resolve.");
        });

    // Wait for expectation to be fulfilled
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatLoadUIImageForRoiSpritePathResolvesToNilIfPathIsNil
{
    // Set fake image path
    [self.slide.managedObjectContext performBlockAndWait:^{
        self.slide.roiSpritePath = nil;
    }];

    // Get UIImage
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    [self.slide loadUIImageForRoiSpritePath]
        .then(^(UIImage *uiImage) {
            XCTAssertNil(uiImage);
            [expectation fulfill];
        })
        .catch(^(NSError *error) {
            XCTFail(@"Expected promise to resolve.");
        });

    // Wait for expectation to be fulfilled
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatLoadUIImageForRoiSpritePathResolvesToNilIfImageDoesNotExistAtPath
{
    // Set fake image path
    NSString *uri = [IMGDocumentsDirectory uriFromPath:@"path/to/image.jpg"];
    [self.slide.managedObjectContext performBlockAndWait:^{
        self.slide.roiSpritePath = uri;
    }];

    // Stub out [IMGDocumentsDirectory loadDataForURI] to resolve with data
    id mock = [OCMockObject mockForClass:[IMGImage class]];
    PMKPromise *promise = [PMKPromise noopPromise];
    [[[mock stub] andReturn:promise] loadDataForURI:[OCMArg any]];

    // Get UIImage
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    [self.slide loadUIImageForRoiSpritePath]
        .then(^(UIImage *uiImage) {
            XCTAssertNil(uiImage);
            [expectation fulfill];
        })
        .catch(^(NSError *error) {
            XCTFail(@"Expected promise to resolve.");
        });

    // Wait for expectation to be fulfilled
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatLoadUIImageForRoiSpritePathSetsOrientationToUp
{
    // Set fake image path
    NSString *uri = [IMGDocumentsDirectory uriFromPath:@"path/to/image.jpg"];
    [self.slide.managedObjectContext performBlockAndWait:^{
        self.slide.roiSpritePath = uri;
    }];

    // Stub out [IMGDocumentsDirectory loadDataForURI] to resolve with data
    id mock = [OCMockObject mockForClass:[IMGImage class]];
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        NSString *imageName = @"fl_01_01";
        NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:imageName ofType:@"jpg"];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        UIImage *orientedImage = [UIImage imageWithCGImage:image.CGImage
                                                     scale:1.0
                                               orientation:UIImageOrientationLeft];
        NSData *data = UIImageJPEGRepresentation(orientedImage, 1.0);
        resolve(data);
    }];
    [[[mock stub] andReturn:promise] loadDataForURI:[OCMArg any]];

    // Get UIImage
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    [self.slide loadUIImageForRoiSpritePath]
        .then(^(UIImage *uiImage) {
            XCTAssertEqual(uiImage.imageOrientation, UIImageOrientationUp);
            [expectation fulfill];
        })
        .catch(^(NSError *error) {
            XCTFail(@"Expected promise to resolve.");
        });

    // Wait for expectation to be fulfilled
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

@end
