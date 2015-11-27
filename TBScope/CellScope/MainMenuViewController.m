//
//  MainMenuViewController.m
//  CellScope
//
//  Created by Frankie Myers on 11/7/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "MainMenuViewController.h"

@implementation MainMenuViewController

- (void)viewDidLoad
{
    //make the navigation bar pretty
    [self.navigationController.navigationBar setTranslucent:YES];
    [self.navigationController.navigationBar setTintColor:[UIColor whiteColor]];
    //[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setSyncIndicator)
                                                 name:@"GoogleSyncStarted"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setSyncIndicator)
                                                 name:@"GoogleSyncStopped"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(setStatusLabels)
                                                 name:@"StatusUpdated"
                                               object:nil];
    
}

- (void)setStatusLabels
{
    float batt = [[TBScopeHardware sharedHardware] batteryVoltage];
    float min = [[NSUserDefaults standardUserDefaults] floatForKey:@"DeadBatteryVoltage"];
    float max = [[NSUserDefaults standardUserDefaults] floatForKey:@"MaxBatteryVoltage"];
    
    int batteryPercentage = MIN(MAX(0,round(((batt-min)/(max-min))*100)),100);
    
    self.batteryIndicatorLabel.text = [NSString stringWithFormat:@"%d%%",batteryPercentage];
    self.temperatureIndicatorLabel.text = [NSString stringWithFormat:@"%2.1f°C",[[TBScopeHardware sharedHardware] temperature]];
    self.humidityIndicatorLabel.text = [NSString stringWithFormat:@"%2.1f%%",[[TBScopeHardware sharedHardware] humidity]];
    self.firmwareIndicatorLabel.text = [NSString stringWithFormat:@"Firmware %d",[[TBScopeHardware sharedHardware] firmwareVersion]];
    
}

- (void)setSyncIndicator
{
    if ([[GoogleDriveSync sharedGDS] isSyncing]) {
        self.syncLabel.hidden = NO;
        [self.syncSpinner startAnimating];
    }
    else {
        self.syncLabel.hidden = YES;
        [self.syncSpinner stopAnimating];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //localization
    [self.navigationItem setTitle:NSLocalizedString(@"Main Menu",nil)];
    self.loggedInAs.text = [NSString stringWithFormat:NSLocalizedString(@"Logged in as: %@",nil),[[[TBScopeData sharedData] currentUser] username]];
    self.syncLabel.text = NSLocalizedString(@"Syncing...", nil);
    self.bluetoothIndicator.text = NSLocalizedString(@"CellScope Connected", nil);
    
    self.cellscopeIDLabel.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"CellScopeID"];
    self.locationLabel.text = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultLocation"];
    NSString *versionNumber = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    NSString *buildId = [NSBundle mainBundle].infoDictionary[@"CFBundleVersion"];
    self.versionLabel.text = [NSString stringWithFormat:@"TBScope %@ (%@)", versionNumber, buildId];
    
    [TBScopeData CSLog:[NSString stringWithFormat:@"TBScope Version %@ (%@)", versionNumber, buildId] inCategory:@"SYSTEM"];
    
    [TBScopeData CSLog:@"Main menu screen presented" inCategory:@"USER"];
    
    [self setSyncIndicator];
    [self setMenuPermissions];
    
    self.statusUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(getStatusUpdate) userInfo:nil repeats:YES];

}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.statusUpdateTimer invalidate];
    self.statusUpdateTimer = nil;
}

- (void)getStatusUpdate
{
    BOOL isConnected = [[TBScopeHardware sharedHardware] isConnected];

    if (isConnected) {
        [[TBScopeHardware sharedHardware] requestStatusUpdate];
    }

    self.bluetoothIndicator.hidden = !isConnected;
    self.bluetoothIcon.hidden = !isConnected;
    self.temperatureIcon.hidden = !isConnected;
    self.temperatureIndicatorLabel.hidden = !isConnected;
    self.humidityIcon.hidden = !isConnected;
    self.humidityIndicatorLabel.hidden = !isConnected;
    self.batteryIcon.hidden = !isConnected;
    self.batteryIndicatorLabel.hidden = !isConnected;
    self.firmwareIndicatorLabel.hidden = !isConnected;
}

- (void)setMenuPermissions
{
    NSString* accessLevel = [[[TBScopeData sharedData] currentUser] accessLevel];
    if ([accessLevel isEqualToString:@"ADMIN"]) {
        self.configurationButton.enabled = YES;
        self.scanSlideButton.enabled = YES;
    }
    else if ([accessLevel isEqualToString:@"USER"]) {
        self.configurationButton.enabled = NO;
        self.scanSlideButton.enabled = YES;
    }
    

}


- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    //only allow slide scanning if there is a cellscope detected
    if([identifier isEqualToString:@"ScanSlideSegue"]) {
        if (![[TBScopeHardware sharedHardware] isConnected] && ![[NSUserDefaults standardUserDefaults] boolForKey:@"AllowScanWithoutCellScope"]) {
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"CellScope Not Connected", nil)
                                                             message:NSLocalizedString(@"Please ensure Bluetooth is enabled and CellScope is powered on.",nil)
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedString(@"OK",nil)
                                                   otherButtonTitles:nil];
            alert.alertViewStyle = UIAlertViewStyleDefault;
            alert.tag = 1;
            [alert show];
            return NO;
        }
        else
            return YES;
    }
    //only allow admin to go to config
    else if ([identifier isEqualToString:@"ConfigurationSegue"]) {
        if ([[[[TBScopeData sharedData] currentUser] accessLevel] isEqualToString:@"ADMIN"]) {
            return YES;
        }
        else
            return NO;
    }
    else
        return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([segue.identifier isEqualToString:@"ScanSlideSegue"])
    {
        
        EditExamViewController* eevc = (EditExamViewController*)[segue destinationViewController];
        eevc.currentExam = nil;
        eevc.isNewExam = YES;
    }
    else if ([segue.identifier isEqualToString:@"ReviewResultsSegue"])
    {

        
    }
    else if ([segue.identifier isEqualToString:@"ConfigurationSegue"])
    {

    }
    
}



- (void)didPressLogout:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [[TBScopeData sharedData] setCurrentUser:nil]; //TODO: log via singleton
}

@end
