//
//  GoogleDriveServiceTests.m
//  TBScope
//
//  Created by Jason Ardell on 11/6/15.
//  Copyright © 2015 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "GoogleDriveService.h"
#import <OCMock/OCMock.h>
#import "PMKPromise+NoopPromise.h"
#import "NSData+MD5.h"

@interface GoogleDriveServiceTests : XCTestCase
@property (strong, nonatomic) GoogleDriveService *service;
@property (strong, nonatomic) NSData *data;
@end

@implementation GoogleDriveServiceTests

- (void)setUp
{
    [super setUp];
    self.service = OCMPartialMock([GoogleDriveService sharedService]);
    self.data = OCMPartialMock([@"Hello World" dataUsingEncoding:NSUTF8StringEncoding]);
}

#pragma getMetadatForFileId: tests

- (void)testThatGetMetadataForFileIdResolvesToNilIfFileIdIsNil
{
    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Call the method
    [self.service getMetadataForFileId:nil]
        .then(^(GTLDriveFile *file) {
            XCTAssertNil(file);
            [expectation fulfill];
        })
        .catch(^{ XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

#pragma fileExists: tests

- (void)testThatFileExistsResolvesToNilIfIdentifierIsNil
{
    // Set up expectation
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];

    // Stub out [GoogleDriveService fileExists:file] to reject
    OCMStub([self.service getMetadataForFileId:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Call the method
    GTLDriveFile *file = [[GTLDriveFile alloc] init];
    file.identifier = nil;
    [self.service fileExists:file]
        .then(^(GTLDriveFile *file) {
            XCTAssertNil(file);
            [expectation fulfill];
        })
        .catch(^{ XCTFail(@"Expected promise to resolve"); });

    // Wait for expectation
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

#pragma listDirectories tests

- (void)testThatListDirectoriesCallsExecuteQueryWithTimeout
{
    // Stub out [GoogleDriveService executeQueryWithTimeout]
    OCMStub([self.service executeQueryWithTimeout:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Call the method
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    [self.service listDirectories]
        .then(^{
            [expectation fulfill];
            OCMVerify([self.service executeQueryWithTimeout:[OCMArg any]]);
        })
        .catch(^(NSError *error) {
            XCTFail(@"Expected promise to resolve");
        });
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

#pragma createDirectoryWithTitle tests

- (void)testThatCreateDirectoryWithTitleCallsExecuteQueryWithTimeout
{
    // Stub out [GoogleDriveService executeQueryWithTimeout]
    OCMStub([self.service executeQueryWithTimeout:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);

    // Call the method
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    [self.service createDirectoryWithTitle:@"test-directory"]
        .then(^{
            [expectation fulfill];
            OCMVerify([self.service executeQueryWithTimeout:[OCMArg any]]);
        })
        .catch(^(NSError *error) {
            XCTFail(@"Expected promise to resolve");
        });
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatCreateDirectoryWithTitleRejectsPromiseWithNilTitle
{
    // Stub out [GoogleDriveService executeQueryWithTimeout]
    OCMStub([self.service executeQueryWithTimeout:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Expected executeQueryWithTimeout NOT to be called");
        });

    // Call the method
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    [self.service createDirectoryWithTitle:nil]
        .then(^{ XCTFail(@"Expected promise to reject."); })
        .catch(^(NSError *error) { [expectation fulfill]; });
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void)testThatCreateDirectoryWithTitleRejectsPromiseWithEmptyTitle
{
    // Stub out [GoogleDriveService executeQueryWithTimeout]
    OCMStub([self.service executeQueryWithTimeout:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Expected executeQueryWithTimeout NOT to be called");
        });

    // Call the method
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    [self.service createDirectoryWithTitle:@""]
        .then(^{ XCTFail(@"Expected promise to reject."); })
        .catch(^(NSError *error) { [expectation fulfill]; });
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

#pragma uploadFile:withData: tests

- (void)testThatUploadFileUploadsIfRemoteFileDoesNotExist
{
    // Stub out [GoogleDriveService fileExists:file] to return resolved
    // promise with a nil argument (no existing remote file)
    OCMStub([self.service fileExists:[OCMArg any]]).andReturn([PMKPromise noopPromise]);

    // Expect [GoogleDriveService executeQueryWithTimeout] to be called with
    // an upload query
    id queryArg = [OCMArg checkWithBlock:^BOOL(GTLQueryDrive *query) {
        // Make sure query is an insert query
        return [[query methodName] isEqual: @"queryForFilesInsertWithObject"];
    }];
    OCMExpect([self.service executeQueryWithTimeout:queryArg])
        .andReturn([PMKPromise noopPromise]);

    // Call the method
    GTLDriveFile *file = [[GTLDriveFile alloc] init];
    file.identifier = @"non-existing identifier";
    [self.service uploadFile:file withData:self.data];
}

- (void)testThatUploadFileDoesNotUploadIfLocalFileHasSameContentsAsRemoteFile
{
    // Stub out fileExists to resolve with a file having a defined md5 checksum
    NSString *md5 = @"abc123";
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = OCMPartialMock([[GTLDriveFile alloc] init]);
        OCMStub([file md5Checksum]).andReturn(md5);
        resolve(file);
    }];
    OCMStub([self.service fileExists:[OCMArg any]]).andReturn(promise);

    // Stub out md5 for upload data
    OCMStub([self.data MD5]).andReturn(md5);

    // Fail if executeQueryWithTimeout is called
    OCMStub([self.service executeQueryWithTimeout:[OCMArg any]])
        .andDo(^(NSInvocation *invocation){
            XCTFail(@"Did not expect executeQueryWithTimeout to be called");
        });

    // Call upload
    GTLDriveFile *newFile = [[GTLDriveFile alloc] init];
    [self.service uploadFile:newFile withData:self.data];
}

- (void)testThatUploadFileUploadsIfLocalFileHasDifferentContentsThanRemoteFile
{
    // Stub out fileExists to resolve with a file having a defined md5 checksum
    NSString *remoteMd5 = @"abc123";
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = OCMPartialMock([[GTLDriveFile alloc] init]);
        OCMStub([file md5Checksum]).andReturn(remoteMd5);
        resolve(file);
    }];
    OCMStub([self.service fileExists:[OCMArg any]]).andReturn(promise);
    
    // Stub out md5 for upload data
    NSString *localMd5 = @"def456";
    OCMStub([self.data MD5]).andReturn(localMd5);
    
    // Expect executeQueryWithTimeout to be called
    id queryArg = [OCMArg checkWithBlock:^BOOL(GTLQueryDrive *query) {
        // Make sure query is an update query
        return [[query methodName] isEqual: @"queryForFilesUpdateWithObject"];
    }];
    OCMExpect([self.service executeQueryWithTimeout:queryArg])
        .andReturn([PMKPromise noopPromise]);
    
    // Call upload
    GTLDriveFile *newFile = [[GTLDriveFile alloc] init];
    [self.service uploadFile:newFile withData:self.data];
}

#pragma deleteFileWithId tests

- (void)testThatDeleteFileWithIdDeletesFileIfItExists
{
    // Stub out fileExists to resolve with a file
    PMKPromise *promise = [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        GTLDriveFile *file = OCMPartialMock([[GTLDriveFile alloc] init]);
        resolve(file);
    }];
    OCMStub([self.service getMetadataForFileId:[OCMArg any]])
        .andReturn(promise);
    
    // Expect executeQueryWithTimeout to be called
    id queryArg = [OCMArg checkWithBlock:^BOOL(GTLQueryDrive *query) {
        // Make sure query is a delete query
        return [[query methodName] isEqual: @"queryForFilesTrashWithFileId"];
    }];
    OCMExpect([self.service executeQueryWithTimeout:queryArg])
        .andReturn([PMKPromise noopPromise]);
    
    // Call delete
    [self.service deleteFileWithId:@"fake-file-id"];
}

- (void)testThatDeleteFileWithIdDoesNothingIfFileDoesNotExistOnServer
{
    // Stub out fileExists to resolve with NO file
    OCMStub([self.service getMetadataForFileId:[OCMArg any]])
        .andReturn([PMKPromise noopPromise]);
    
    // Expect executeQueryWithTimeout NOT to be called
    OCMStub([self.service executeQueryWithTimeout:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTFail(@"Did not expect executeQueryWithTimeout to be called");
        });
    
    // Call delete
    [self.service deleteFileWithId:@"fake-file-id"];
}

#pragma executeQueryWithTimeout tests

- (void) testThatExecuteQueryWithTimeoutRunsQueryOnMainThread {
    // Stub out GoogleDriveService.driveService executeQuery:completionHandler:
    // to check whether query was run on the main thread
    id mockDriveService = OCMPartialMock([self.service driveService]);
    OCMStub([mockDriveService executeQuery:[OCMArg any] completionHandler:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            XCTAssert([[NSThread currentThread] isMainThread]);
        });
    self.service.driveService = (GTLServiceDrive *)mockDriveService;

    // Call the method on a bg thread
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [self.service executeQueryWithTimeout:[[GTLQuery alloc] init]];
        [expectation fulfill];
    });
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void) testThatExecuteQueryWithTimeoutResolvesPromiseOnSuccessfulResponse {
    // Stub out GoogleDriveService.driveService executeQuery:completionHandler:
    // to call completionHandler with a successful response
    id mockDriveService = OCMPartialMock([self.service driveService]);
    OCMStub([mockDriveService executeQuery:[OCMArg any] completionHandler:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            __unsafe_unretained void(^completionHandler)(GTLServiceTicket *ticket, id object, NSError *error);
            [invocation getArgument:&completionHandler atIndex:3];
            completionHandler(
                [[GTLServiceTicket alloc] init],
                @"Successful response",
                nil
            );
        });
    self.service.driveService = (GTLServiceDrive *)mockDriveService;

    // Call executeQueryWithTimeout:
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    PMKPromise *promise = [self.service executeQueryWithTimeout:[[GTLQueryDrive alloc] init]];
    promise
        .then(^{ [expectation fulfill]; })
        .catch(^{ XCTFail(@"Did not expect catch to be called."); });

    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void) testThatExecuteQueryWithTimeoutRejectsPromiseOnFailedResponse {
    // Stub out GoogleDriveService.driveService executeQuery:completionHandler:
    // to call completionHandler with an error
    id mockDriveService = OCMPartialMock([self.service driveService]);
    OCMStub([mockDriveService executeQuery:[OCMArg any] completionHandler:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            __unsafe_unretained void(^completionHandler)(GTLServiceTicket *ticket, id object, NSError *error);
            [invocation getArgument:&completionHandler atIndex:3];
            completionHandler(
                [[GTLServiceTicket alloc] init],
                @"Unsuccessful response",
                [[NSError alloc] init]
            );
        });
    self.service.driveService = (GTLServiceDrive *)mockDriveService;
    
    // Call executeQueryWithTimeout:
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    PMKPromise *promise = [self.service executeQueryWithTimeout:[[GTLQueryDrive alloc] init]];
    promise
        .then(^{ XCTFail(@"Did not expect then to be called."); })
        .catch(^{ [expectation fulfill]; });
    
    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

- (void) testThatExecuteQueryWithTimeoutRejectsPromiseAfterTimeout {
    // Stub out googleDriveTimeout (for speed!)
    OCMStub([self.service googleDriveTimeout]).andReturn(0.5);
    
    // Stub out GoogleDriveService.driveService executeQuery:completionHandler:
    // to call completionHandler with a successful response
    id mockDriveService = OCMPartialMock([self.service driveService]);
    OCMStub([mockDriveService executeQuery:[OCMArg any] completionHandler:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            // Don't (ever) call completion handler
        });
    self.service.driveService = (GTLServiceDrive *)mockDriveService;

    // Call executeQueryWithTimeout:
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for async call to finish"];
    PMKPromise *promise = [self.service executeQueryWithTimeout:[[GTLQueryDrive alloc] init]];
    promise
        .then(^{ XCTFail(@"Did not expect then to be called."); })
        .catch(^{ [expectation fulfill]; });
    
    [self waitForExpectationsWithTimeout:2.0 handler:^(NSError *error) {
        if (error) XCTFail(@"Async test timed out");
    }];
}

@end
