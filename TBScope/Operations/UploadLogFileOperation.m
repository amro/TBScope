//
//  UploadLogFileOperation.m
//  TBScope
//
//  Created by Jason Ardell on 4/2/16.
//  Copyright © 2016 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "UploadLogFileOperation.h"
#import <CoreData/CoreData.h>
#import "TBScopeData.h"

@implementation UploadLogFileOperation

- (void)start
{
    if ([self isCancelled])
    {
        // Move the operation to the finished state if it is canceled.
        [self willChangeValueForKey:@"isFinished"];
        self._finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    // If the operation is not canceled, begin executing the task.
    [self willChangeValueForKey:@"isExecuting"];
    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    self._executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)main;
{
    if ([self isCancelled]) {
        return;
    }
    
    NSManagedObjectContext *moc = [[TBScopeData sharedData] managedObjectContext];
    [moc performBlock:^{
        NSPredicate* pred = [NSPredicate predicateWithFormat:@"(synced == NO)"];
        NSArray *results = [CoreDataHelper searchObjectsForEntity:@"Logs"
                                                    withPredicate:pred
                                                       andSortKey:@"date"
                                                 andSortAscending:YES
                                                       andContext:moc];

        if ([results count] <= 0) {
            // Nothing to do
            [self completeOperation];
            return;
        }

        NSLog(@"UPLOADING LOG FILE");

        // Build text file
        NSMutableString* outString = [[NSMutableString alloc] init];
        for (Logs* logEntry in results) {
            logEntry.synced = YES;
            [outString appendFormat:@"%@\t%@\t%@\n", logEntry.date, logEntry.category, logEntry.entry];
        }

        // Create a google file object from this image
        GTLDriveFile *file = [GTLDriveFile object];
        file.title = [NSString stringWithFormat:@"%@ - %@.log",
            [[NSUserDefaults standardUserDefaults] stringForKey:@"CellScopeID"],
            [TBScopeData stringFromDate:[NSDate date]]
        ];
        file.descriptionProperty = @"Uploaded from CellScope";
        file.mimeType = @"text/plain";
        NSData *data = [outString dataUsingEncoding:NSUTF8StringEncoding];

        // Upload the file
        GoogleDriveService *service = [GoogleDriveService sharedService];
        [service uploadFile:file withData:data]
            .then(^(GTLDriveFile *insertedFile) {
                [[TBScopeData sharedData] saveCoreData];
                [self completeOperation];
            });
    }];
}

- (BOOL) isAsynchronous;
{
    return YES;
}

- (BOOL)isExecuting {
    return self._executing;
}

- (BOOL)isFinished {
    return self._finished;
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    
    self._executing = NO;
    self._finished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

@end
