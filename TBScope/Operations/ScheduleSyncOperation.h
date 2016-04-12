//
//  ScheduleSyncOperation.h
//  TBScope
//
//  Created by Jason Ardell on 4/3/16.
//  Copyright © 2016 UC Berkeley Fletcher Lab. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ScheduleSyncOperation : NSOperation
@property (atomic, assign) BOOL _executing;
@property (atomic, assign) BOOL _finished;
@end
