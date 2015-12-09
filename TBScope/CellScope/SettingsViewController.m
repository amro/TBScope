//
//  SettingsViewController.m
//  TBScope
//
//  Created by Frankie Myers on 11/20/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "SettingsViewController.h"


@implementation SettingsViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [self fetchValuesFromPreferences];
    
    [TBScopeData CSLog:@"Settings screen presented" inCategory:@"USER"];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self saveValuesToPreferences];
}

- (IBAction)didPressResetSettings
{
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    
    //TODO: add "are you sure" popup
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [prefs removePersistentDomainForName:appDomain];
    
    //override the default for resetting the database
    [prefs setBool:NO forKey:@"ResetCoreDataOnStartup"];
    [prefs synchronize];
    
    [self fetchValuesFromPreferences];
}

- (void)fetchValuesFromPreferences
{
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    
    self.cellscopeID.text = [prefs stringForKey:@"CellScopeID"];
    self.numPatchesToAverage.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"NumPatchesToAverage"]];
    self.defaultLocation.text = [prefs stringForKey:@"DefaultLocation"];
    self.patientIDFormat.text = [[NSString alloc] initWithFormat:@"%@",[prefs stringForKey:@"PatientIDFormat"]];
    self.redThreshold.text = [[NSString alloc] initWithFormat:@"%2.3f",[prefs floatForKey:@"RedThreshold"]];
    self.yellowThreshold.text = [[NSString alloc] initWithFormat:@"%2.3f",[prefs floatForKey:@"YellowThreshold"]];
    self.diagnosticThreshold.text = [[NSString alloc] initWithFormat:@"%2.3f",[prefs floatForKey:@"DiagnosticThreshold"]];
    self.autoAnalyzeSwitch.on = [prefs boolForKey:@"DoAutoAnalyze"];
    self.bypassLogin.on = [prefs boolForKey:@"BypassLogin"];
    self.resetCoreData.on = [prefs boolForKey:@"ResetCoreDataOnStartup"];
    
    self.syncInterval.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"SyncInterval"]];
    self.maxUploadsPerSlide.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"MaxUploadsPerSlide"]];
    self.wifiOnlyButton.on = [prefs boolForKey:@"WifiSyncOnly"];

    NSString *syncDirectoryName = [prefs stringForKey:@"RemoteDirectoryTitle"];
    if (syncDirectoryName) {
        self.syncDirectoryName.text = [[NSString alloc] initWithFormat:@"%@", syncDirectoryName];
    } else {
        self.syncDirectoryName.text = @"(root directory)";
    }

    self.autoLoadSwitch.on = [prefs boolForKey:@"DoAutoLoadSlide"];
    self.autoScanSwitch.on = [prefs boolForKey:@"DoAutoScan"];
    self.runWithoutCellScopeSwitch.on = [prefs boolForKey:@"AllowScanWithoutCellScope"];
    
    self.scanColumns.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"AutoScanCols"]];
    self.scanRows.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"AutoScanRows"]];
    self.fieldSpacing.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"AutoScanStepsBetweenFields"]];
    self.refocusInterval.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"AutoScanFocusInterval"]];
    self.bfIntensity.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"AutoScanBFIntensity"]];
    self.fluorIntensity.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"AutoScanFluorescentIntensity"]];
    
    self.bypassDataEntrySwitch.on = [prefs boolForKey:@"BypassDataEntry"];
    
    self.maxAFFailures.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"MaxAFFailures"]];
    
    self.cameraExposureDurationBF.text    = [[NSString alloc] initWithFormat:@"%d", (int)[prefs floatForKey:@"CameraExposureDurationBF"]];
    self.cameraISOSpeedBF.text            = [[NSString alloc] initWithFormat:@"%d", (int)[prefs floatForKey:@"CameraISOSpeedBF"]];
    self.cameraExposureDurationFL.text    = [[NSString alloc] initWithFormat:@"%d", (int)[prefs floatForKey:@"CameraExposureDurationFL"]];
    self.cameraISOSpeedFL.text            = [[NSString alloc] initWithFormat:@"%d", (int)[prefs floatForKey:@"CameraISOSpeedFL"]];
    self.cameraWhiteBalanceRedGain.text   = [[NSString alloc] initWithFormat:@"%d", (int)[prefs floatForKey:@"CameraWhiteBalanceRedGain"]];
    self.cameraWhiteBalanceGreenGain.text = [[NSString alloc] initWithFormat:@"%d", (int)[prefs floatForKey:@"CameraWhiteBalanceGreenGain"]];
    self.cameraWhiteBalanceBlueGain.text  = [[NSString alloc] initWithFormat:@"%d", (int)[prefs floatForKey:@"CameraWhiteBalanceBlueGain"]];

    self.stageSettlingTime.text = [[NSString alloc] initWithFormat:@"%2.3f",[prefs floatForKey:@"StageSettlingTime"]];
    self.focusSettlingTime.text = [[NSString alloc] initWithFormat:@"%2.3f",[prefs floatForKey:@"FocusSettlingTime"]];
    self.stageStepDuration.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"StageStepInterval"]];
    self.focusStepDuration.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"FocusStepInterval"]];
    
    self.backlash.text = [[NSString alloc] initWithFormat:@"%ld",[prefs integerForKey:@"StageBacklashSteps"]];
    self.emptyFieldThreshold.text = [[NSString alloc] initWithFormat:@"%2.3f",[prefs floatForKey:@"EmptyContentThreshold"]];
    self.boundaryFieldThreshold.text = [[NSString alloc] initWithFormat:@"%2.3f",[prefs floatForKey:@"BoundaryScoreThreshold"]];
    self.uploadSwitch.on = [prefs boolForKey:@"UploadEnabled"];
    self.downloadSwitch.on = [prefs boolForKey:@"DownloadEnabled"];
    self.debuggingSwitch.on = [prefs boolForKey:@"DebugMode"];
    
    
}

- (void)saveValuesToPreferences
{
    
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    NSString* alertString = @"";
    
    //TODO: add some data validation for each field and finish with all the fields...
    if (self.cellscopeID.text.length==0)
        alertString = @"CellScope ID cannot be blank.";
    else
        [prefs setValue:self.cellscopeID.text forKey:@"CellScopeID"];

    if (self.patientIDFormat.text.length==0)
        alertString = @"Patient ID format cannot be blank.";
    else
        [prefs setValue:self.patientIDFormat.text forKey:@"PatientIDFormat"];
    
    [prefs setValue:self.defaultLocation.text forKey:@"DefaultLocation"];
    
    [prefs setInteger:self.numPatchesToAverage.text.integerValue forKey:@"NumPatchesToAverage"];
    [prefs setInteger:self.syncInterval.text.integerValue forKey:@"SyncInterval"];
    [prefs setInteger:self.maxUploadsPerSlide.text.integerValue forKey:@"MaxUploadsPerSlide"];
    
    [prefs setFloat:self.diagnosticThreshold.text.floatValue forKey:@"DiagnosticThreshold"];
    [prefs setFloat:self.redThreshold.text.floatValue forKey:@"RedThreshold"];
    [prefs setFloat:self.yellowThreshold.text.floatValue forKey:@"YellowThreshold"];
    
    [prefs setBool:self.bypassLogin.on forKey:@"BypassLogin"];
    [prefs setBool:self.resetCoreData.on forKey:@"ResetCoreDataOnStartup"];
    [prefs setBool:self.wifiOnlyButton.on forKey:@"WifiSyncOnly"];
    
    [prefs setBool:self.autoAnalyzeSwitch.on forKey:@"DoAutoAnalyze"];
    [prefs setBool:self.autoScanSwitch.on forKey:@"DoAutoScan"];
    [prefs setBool:self.autoLoadSwitch.on forKey:@"DoAutoLoadSlide"];
    [prefs setBool:self.bypassDataEntrySwitch.on forKey:@"BypassDataEntry"];
    [prefs setBool:self.runWithoutCellScopeSwitch.on forKey:@"AllowScanWithoutCellScope"];
    
    [prefs setInteger:self.scanColumns.text.integerValue forKey:@"AutoScanCols"];
    [prefs setInteger:self.scanRows.text.integerValue forKey:@"AutoScanRows"];
    [prefs setInteger:self.fieldSpacing.text.integerValue forKey:@"AutoScanStepsBetweenFields"];
    [prefs setInteger:self.refocusInterval.text.integerValue forKey:@"AutoScanFocusInterval"];
    [prefs setInteger:self.bfIntensity.text.integerValue forKey:@"AutoScanBFIntensity"];
    [prefs setInteger:self.fluorIntensity.text.integerValue forKey:@"AutoScanFluorescentIntensity"];
    
    [prefs setInteger:self.maxAFFailures.text.integerValue forKey:@"MaxAFFailures"];
    
    [prefs setInteger:self.cameraExposureDurationBF.text.integerValue forKey:@"CameraExposureDurationBF"];
    [prefs setInteger:self.cameraISOSpeedBF.text.integerValue forKey:@"CameraISOSpeedBF"];
    [prefs setInteger:self.cameraExposureDurationFL.text.integerValue forKey:@"CameraExposureDurationFL"];
    [prefs setInteger:self.cameraISOSpeedFL.text.integerValue forKey:@"CameraISOSpeedFL"];
    [prefs setInteger:self.cameraWhiteBalanceRedGain.text.integerValue forKey:@"CameraWhiteBalanceRedGain"];
    [prefs setInteger:self.cameraWhiteBalanceGreenGain.text.integerValue forKey:@"CameraWhiteBalanceGreenGain"];
    [prefs setInteger:self.cameraWhiteBalanceBlueGain.text.integerValue forKey:@"CameraWhiteBalanceBlueGain"];
    
    [prefs setInteger:self.focusStepDuration.text.integerValue forKey:@"FocusStepInterval"];
    [prefs setInteger:self.stageStepDuration.text.integerValue forKey:@"StageStepInterval"];
    [prefs setFloat:self.focusSettlingTime.text.floatValue forKey:@"FocusSettlingTime"];
    [prefs setFloat:self.stageSettlingTime.text.floatValue forKey:@"StageSettlingTime"];
    
    [prefs setInteger:self.backlash.text.integerValue forKey:@"StageBacklashSteps"];
    [prefs setFloat:self.emptyFieldThreshold.text.floatValue forKey:@"EmptyContentThreshold"];
    [prefs setFloat:self.boundaryFieldThreshold.text.floatValue forKey:@"BoundaryScoreThreshold"];
    [prefs setBool:self.uploadSwitch.on forKey:@"UploadEnabled"];
    [prefs setBool:self.downloadSwitch.on forKey:@"DownloadEnabled"];
    [prefs setBool:self.debuggingSwitch.on forKey:@"DebugMode"];
    
        
    if ([alertString isEqualToString:@""])
        [prefs synchronize];
    
}

@end
