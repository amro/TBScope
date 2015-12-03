//
//  AppDelegate.m
//  CellScope
//
//  Created by UC Berkeley Fletcher Lab on 8/19/12.
//  Copyright (c) 2012 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "CSAppDelegate.h"

@implementation CSAppDelegate

@synthesize expirationHandler;
@synthesize bgTask;

void onUncaughtException(NSException* exception)
{
    [TBScopeData CSLog:[exception description] inCategory:@"ERROR"];
    [TBScopeData CSLog:[[NSThread callStackSymbols] description] inCategory:@"ERROR"];
    [[TBScopeData sharedData] saveCoreData];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSSetUncaughtExceptionHandler(&onUncaughtException);
    
    NSString *versionNumber = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    NSString *buildId = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
    
    [TBScopeData CSLog:[NSString stringWithFormat:@"TBScope App Started, Version %@ (%@)", versionNumber, buildId] inCategory:@"SYSTEM"];
    
    //provide some general stats on the iPad state (mem? other apps? battery? GPS location? what else is useful?)
    [TBScopeData CSLog:[NSString stringWithFormat:@"Current language: %@" ,[[NSLocale preferredLanguages] objectAtIndex:0]]
            inCategory:@"SYSTEM"];
    
    // Setup defaults for preference file
    NSString* defaultPrefsFile = [[NSBundle mainBundle] pathForResource:@"default-configuration" ofType:@"plist"];
    NSDictionary* defaultPreferences = [NSDictionary dictionaryWithContentsOfFile:defaultPrefsFile];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultPreferences];
    
    //start bluetooth connection
    [[TBScopeHardware sharedHardware] setupBLEConnection];
    [[TBScopeHardware sharedHardware] setupEnvironmentalLogging];
    
    //setup location services
    //set up location manager for geotagging photos
    [[TBScopeData sharedData] startGPS];
    

    // if this is the first time the app has run, or if the Reset Button was pressed in config settings, this will initialize core data
    // note that at this point, the database has already been deleted (that happened when the message was sent to managedObjectContext
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ResetCoreDataOnStartup"])
    {
        [TBScopeData CSLog:@"Re-initializing Core Data" inCategory:@"SYSTEM"];
        //NSLog(@"Re-initializing Core Data...");
        
        // Set flag so we know not to run this next time
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ResetCoreDataOnStartup"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        
        [[TBScopeData sharedData] resetCoreData];
        
    }
    
    
    //dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[GoogleDriveSync sharedGDS] doSync]; //gets the ball rolling for sync
    //});

    /*
    
        UIApplication* app = [UIApplication sharedApplication];
        
        self.expirationHandler = ^{
            [app endBackgroundTask:self.bgTask];
            self.bgTask = UIBackgroundTaskInvalid;
            self.bgTask = [app beginBackgroundTaskWithExpirationHandler:expirationHandler];
            NSLog(@"Expired");
            self.jobExpired = YES;
            while(self.jobExpired) {
                // spin while we wait for the task to actually end.
                [NSThread sleepForTimeInterval:1];
            }
            // Restart the background task so we can run forever.
            [self startBackgroundTask];
        };
        self.bgTask = [app beginBackgroundTaskWithExpirationHandler:expirationHandler];
    
    [self initiateBackgroundTask];
    */
    
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [TBScopeData CSLog:@"App terminating" inCategory:@"SYSTEM"];
    
    [[TBScopeData sharedData] saveCoreData];
    
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    [TBScopeData CSLog:@"App is inactive" inCategory:@"SYSTEM"];
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [TBScopeData CSLog:@"App entered background" inCategory:@"SYSTEM"];
    //[self initiateBackgroundTask];
    
}

- (void)initiateBackgroundTask
{
    self.background = YES;
    [self startBackgroundTask];
}

- (void)startBackgroundTask
{

    NSLog(@"Restarting task");
    // Start the long-running task.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // When the job expires it still keeps running since we never exited it. Thus have the expiration handler
        // set a flag that the job expired and use that to exit the while loop and end the task.
        while(self.background && !self.jobExpired)
        {
            [NSThread sleepForTimeInterval:1]; //dummy task
        }
        
        self.jobExpired = NO;
    });
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
    
    [TBScopeData CSLog:@"App is active" inCategory:@"SYSTEM"];
    self.background = NO;
}


#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
/*- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}*/

@end
