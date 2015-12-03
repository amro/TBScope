//
//  CaptureViewController.m
//  CellScope
//
//  Created by Frankie Myers on 11/7/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "CaptureViewController.h"
#import "TBScopeCamera.h"
#import "TBScopeFocusManager.h"

BOOL _FLOn=NO;
BOOL _BFOn=NO;
BOOL _isAborting=NO;
BOOL _isWaitingForFocusConfirmation=NO;
BOOL _didPressManualFocus=NO;
int _manualRefocusStepCounter=0;

AVAudioPlayer* _avPlayer;

@implementation CaptureViewController

@synthesize currentSlide,snapButton,analyzeButton,holdTimer;

@synthesize previewView;

- (void)viewDidLoad
{

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
    //localization
    self.navigationItem.rightBarButtonItem.title = NSLocalizedString(@"Next", nil);    
    [self.bfButton setTitle:NSLocalizedString(@"BF Off",nil) forState:UIControlStateNormal];
    [self.flButton setTitle:NSLocalizedString(@"FL Off",nil) forState:UIControlStateNormal];
    //[self.aeButton setTitle:NSLocalizedString(@"AE On",nil) forState:UIControlStateNormal];
    self.analyzeButton.title = NSLocalizedString(@"Analyze",nil);
    [self.fastSlowButton setTitle:NSLocalizedString(@"Fast",nil) forState:UIControlStateNormal];
    [self.autoFocusButton setTitle:NSLocalizedString(@"Focus", nil) forState:UIControlStateNormal];
    [self.autoScanButton setTitle:NSLocalizedString(@"Auto Scan", nil) forState:UIControlStateNormal];
    [self.abortButton setTitle:NSLocalizedString(@"Abort", nil) forState:UIControlStateNormal];
    [self.refocusButton setTitle:NSLocalizedString(@"Re-Focus", nil) forState:UIControlStateNormal];
    
    
    //setup the camera view
    [previewView setUpPreview];
    [previewView setBouncesZoom:NO];
    [previewView setBounces:NO];
    [previewView setMaximumZoomScale:10.0];
    [previewView zoomExtents]; //TODO: doesn't seem to be working right
    
    self.currentField = 0; //reset the field counter
    [self updatePrompt];
    self.snapButton.enabled = YES;
    self.snapButton.alpha = 1.0;
    
    self.analyzeButton.enabled = NO;
    self.analyzeButton.tintColor = [UIColor grayColor];
    
    [previewView setAutoresizesSubviews:NO];  //TODO: necessary?
    
    //[[TBScopeCamera sharedCamera] setExposureLock:YES];
    //[[TBScopeCamera sharedCamera] setFocusLock:YES];
    
    self.analyzeButton.enabled = NO;
    
    //TODO: i'd rather do this as a delegate
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveImageCallback:)
                                                 name:@"ImageCaptured"
                                               object:nil];

    //if this slide is being rescanned, delete old images/results
    for (Images* im in self.currentSlide.slideImages) {
        [[[TBScopeData sharedData] managedObjectContext] deleteObject:im];
    }
    if (self.currentSlide.slideAnalysisResults!=nil)
        [[[TBScopeData sharedData] managedObjectContext] deleteObject:self.currentSlide.slideAnalysisResults];
    [[TBScopeData sharedData] saveCoreData];
    
    [[TBScopeHardware sharedHardware] setDelegate:self];
    
    self.currentSpeed = CSStageSpeedFast;
    
    _isAborting = NO;
    
    self.controlPanelView.hidden = NO;
    self.leftButton.hidden = NO;
    self.rightButton.hidden = NO;
    self.downButton.hidden = NO;
    self.upButton.hidden = NO;
    self.autoFocusButton.hidden = NO;
    self.autoScanButton.hidden = NO;
    self.scanStatusLabel.hidden = YES;
    self.abortButton.hidden = YES;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMode"]) {
        [NSTimer scheduledTimerWithTimeInterval:(float)0.5 target:self selector:@selector(updateCoordinateLabel) userInfo:nil repeats:YES];
        self.coordinateLabel.hidden = NO;
    }

    
    [TBScopeData CSLog:@"Capture screen presented" inCategory:@"USER"];

    [NSThread sleepForTimeInterval:1];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DoAutoScan"]) {
        [self didPressAutoScan:nil];
    }
    else
    {
        [self didPressMoveCenter:nil];
    }
}

- (void)didPressAbort:(id)sender
{
    [TBScopeData CSLog:@"User pressed abort." inCategory:@"CAPTURE"];
    _isAborting = YES;
}

- (void)didPressManualFocus:(id)sender
{
    [TBScopeData CSLog:@"User requested manual re-focus." inCategory:@"CAPTURE"];
    _didPressManualFocus = YES;
}

- (void)updatePrompt
{
    
    self.navigationItem.title = NSLocalizedString(@"Calibration Mode",nil);
}

- (void)updateCoordinateLabel
{
    int x = [[TBScopeHardware sharedHardware] xPosition];
    int y = [[TBScopeHardware sharedHardware] yPosition];
    int z = [[TBScopeHardware sharedHardware] zPosition];
    [self.coordinateLabel setText:[NSString stringWithFormat:@"(%d, %d, %d)",x,y,z]];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([segue.identifier isEqualToString:@"AnalysisSegue"]) {
        AnalysisViewController *avc = (AnalysisViewController*)[segue destinationViewController];
        avc.currentSlide = self.currentSlide;
        avc.showResultsAfterAnalysis = YES;
        
        //raise objective
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZHome];
        
        //eject slide
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionLoading];
        
        //draw it back in (after user removes slide)
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionHome];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
   
    [[self navigationController] setNavigationBarHidden:NO animated:YES];
    
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
    [[TBScopeHardware sharedHardware] disableMotors];
    
    [self.previewView takeDownCamera];
    
    
    [super viewWillDisappear:animated];
}

- (void)abortCapture
{
    [TBScopeData CSLog:@"Scan aborted by user." inCategory:@"USER"];
    [[self navigationController] popViewControllerAnimated:YES];
}

- (void)didPressCapture:(id)sender
{
    if ([[TBScopeCamera sharedCamera] isPreviewRunning])
    {
        // Grab image in background thread; otherwise it may be delayed due
        // to focusing, etc.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            [previewView grabImage];
        });
    } else {
        [[TBScopeCamera sharedCamera] startPreview];
        self.analyzeButton.enabled = NO;
    }
}



- (void)saveImageCallback:(NSNotification *)notification
{
    // Pull image/state info from the dictionary
    NSDictionary *dict = notification.userInfo;
    int xPosition = (int)dict[@"xPosition"];
    int yPosition = (int)dict[@"yPosition"];
    int zPosition = (int)dict[@"zPosition"];
    UIImage *image = [UIImage imageWithData:dict[@"data"]];

    // Log the capture
    NSString *message = [NSString stringWithFormat:@"Snapped an image at %d:%d:%d", xPosition, yPosition, zPosition];
    [TBScopeData CSLog:message inCategory:@"CAPTURE"];

    [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
        ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
        ALAssetOrientation orientation = [image imageOrientation];
        [library writeImageToSavedPhotosAlbum:image.CGImage
                                  orientation:orientation
                              completionBlock:^(NSURL* assetUrl, NSError* error) {
                                  if (error) {
                                      resolve(error);
                                  } else {
                                      resolve(assetUrl);
                                  }
                              }];
    }].then(^(NSURL *assetURL) {
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            // Create a temporary managed object context
            NSManagedObjectContext *mainMOC = [[TBScopeData sharedData] managedObjectContext];
            NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            moc.parentContext = mainMOC;

            // Create our new image and set attributes
            NSString *path = assetURL.absoluteString;
            int fieldNumber = self.currentField+1;
            [moc performBlockAndWait:^{
                Images* newImage = (Images*)[NSEntityDescription insertNewObjectForEntityForName:@"Images"
                                                                          inManagedObjectContext:moc];
                newImage.path = path;
                newImage.fieldNumber = fieldNumber;
                newImage.metadata = @"";  //this data is no longer useful
                newImage.xCoordinate = xPosition;
                newImage.yCoordinate = yPosition;
                newImage.zCoordinate = zPosition;
                newImage.slide = [moc objectWithID:self.currentSlide.objectID];

                // Save temporary managed object context
                NSError *error;
                if (![moc save:&error]) {
                    resolve(error);
                    return;
                }
            }];

            // Save core data
            [mainMOC performBlock:^{
                [TBScopeData touchExam:self.currentSlide.exam];
                [[TBScopeData sharedData] saveCoreData];
                [TBScopeData CSLog:[NSString stringWithFormat:@"Saved image for %@ - %d-%d, to filename: %@",
                                    self.currentSlide.exam.examID,
                                    self.currentSlide.slideNumber,
                                    fieldNumber,
                                    path]
                        inCategory:@"CAPTURE"];
                resolve(nil);
            }];
        }];
    }).then(^{
        return [PMKPromise promiseWithResolver:^(PMKResolver resolve) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.currentField++;
                self.analyzeButton.enabled = YES;
                self.analyzeButton.tintColor = [UIColor whiteColor];
                resolve(nil);
            });
        }];
    }).catch(^(NSError *error) {
        NSString *message = [NSString stringWithFormat:@"Error saving photo: %@", error.description];
        [TBScopeData CSLog:message inCategory:@"CAPTURE"];
    });
}


- (IBAction)didTouchDownStageButton:(id)sender
{
    if (holdTimer)
    {
        [holdTimer invalidate];
        holdTimer = nil;
    }
    
    UIButton* buttonPressed = (UIButton*)sender;
    
    //TODO: refactor this to use sender, rather than tags
    if (buttonPressed.tag==1) //up
        self.currentDirection = CSStageDirectionLeft;
    else if (buttonPressed.tag==2) //down
        self.currentDirection = CSStageDirectionRight;
    else if (buttonPressed.tag==3) //left
        self.currentDirection = CSStageDirectionUp;
    else if (buttonPressed.tag==4) //right
        self.currentDirection = CSStageDirectionDown;
    else if (buttonPressed.tag==5) //z+
        self.currentDirection = CSStageDirectionFocusUp;
    else if (buttonPressed.tag==6) //z-
        self.currentDirection = CSStageDirectionFocusDown;
    
    if (self.currentDirection==CSStageDirectionFocusDown || self.currentDirection==CSStageDirectionFocusUp)
        [[TBScopeHardware sharedHardware] setStepperInterval:[[NSUserDefaults standardUserDefaults] integerForKey:@"FocusStepInterval"]];
    else
        [[TBScopeHardware sharedHardware] setStepperInterval:[[NSUserDefaults standardUserDefaults] integerForKey:@"StageStepInterval"]];
    
    holdTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(moveStage:) userInfo:nil repeats:YES];
    
}

- (IBAction)didPressManualFocusOk:(id)sender
{
    [[TBScopeHardware sharedHardware] disableMotors];
    [NSThread sleepForTimeInterval:0.1];
    _isWaitingForFocusConfirmation = NO;
}

- (IBAction)didPressStressTest:(id)sender
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        
        //setup UI
        dispatch_async(dispatch_get_main_queue(), ^(void){
            self.controlPanelView.hidden = YES;
            self.leftButton.hidden = YES;
            self.rightButton.hidden = YES;
            self.downButton.hidden = YES;
            self.upButton.hidden = YES;
            self.intensitySlider.hidden = YES;
            self.intensityLabel.hidden = YES;
            self.autoFocusButton.hidden = YES;
            self.autoScanButton.hidden = YES;
            self.scanStatusLabel.hidden = NO;
            self.abortButton.hidden = NO;
            self.refocusButton.hidden = YES;
            [[self navigationController] setNavigationBarHidden:YES animated:YES];
        });
        
        int cycleNum = 1;
        while (!_isAborting) {

            //update label on UI
            dispatch_async(dispatch_get_main_queue(), ^(void){
                self.scanStatusLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Cycle %d", nil), cycleNum];
            });
            
            //take a picture
            [self didPressCapture:nil];
            [NSThread sleepForTimeInterval:0.5];
            
            //move stage/focus
            for (int i=0; i<10; i++) {
                [[TBScopeHardware sharedHardware] moveStageWithDirection:CSStageDirectionLeft
                                                                   Steps:100
                                                             StopOnLimit:YES
                                                            DisableAfter:YES];
                [[TBScopeHardware sharedHardware] waitForStage];
            }
            for (int i=0; i<10; i++) {
                [[TBScopeHardware sharedHardware] moveStageWithDirection:CSStageDirectionDown
                                                                   Steps:100
                                                             StopOnLimit:YES
                                                            DisableAfter:YES];
                [[TBScopeHardware sharedHardware] waitForStage];
            }
            for (int i=0; i<10; i++) {
                [[TBScopeHardware sharedHardware] moveStageWithDirection:CSStageDirectionRight
                                                                   Steps:100
                                                             StopOnLimit:YES
                                                            DisableAfter:YES];
                [[TBScopeHardware sharedHardware] waitForStage];
            }
            for (int i=0; i<10; i++) {
                [[TBScopeHardware sharedHardware] moveStageWithDirection:CSStageDirectionUp
                                                                   Steps:100
                                                             StopOnLimit:YES
                                                            DisableAfter:YES];
                [[TBScopeHardware sharedHardware] waitForStage];
            }
            for (int i=0; i<10; i++) {
                [[TBScopeHardware sharedHardware] moveStageWithDirection:CSStageDirectionFocusUp
                                                                   Steps:100
                                                             StopOnLimit:YES
                                                            DisableAfter:YES];
                [[TBScopeHardware sharedHardware] waitForStage];
            }
            for (int i=0; i<20; i++) {
                [[TBScopeHardware sharedHardware] moveStageWithDirection:CSStageDirectionFocusDown
                                                                   Steps:100
                                                             StopOnLimit:YES
                                                            DisableAfter:YES];
                [[TBScopeHardware sharedHardware] waitForStage];
            }
            for (int i=0; i<10; i++) {
                [[TBScopeHardware sharedHardware] moveStageWithDirection:CSStageDirectionFocusUp
                                                                   Steps:100
                                                             StopOnLimit:YES
                                                            DisableAfter:YES];
                [[TBScopeHardware sharedHardware] waitForStage];
            }
            
            
            cycleNum++;
        }
        
        //reset UI controls
        dispatch_async(dispatch_get_main_queue(), ^(void){
            self.controlPanelView.hidden = NO;
            self.leftButton.hidden = NO;
            self.rightButton.hidden = NO;
            self.downButton.hidden = NO;
            self.upButton.hidden = NO;
            self.autoFocusButton.hidden = NO;
            self.autoScanButton.hidden = NO;
            self.scanStatusLabel.hidden = YES;
            self.abortButton.hidden = YES;
            self.refocusButton.hidden = YES;
            [[self navigationController] setNavigationBarHidden:NO animated:YES];
            
        });
    });
}

- (void) toggleBF:(BOOL)on
{
    if (on)
    {
        int intensity = [[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanBFIntensity"];
        self.intensitySlider.hidden = NO;
        self.intensityLabel.hidden = NO;
        [self.intensitySlider setValue:(float)intensity/255];
        [self.intensityLabel setText:[NSString stringWithFormat:@"%d",intensity]];
        
        self.intensitySlider.tintColor = [UIColor greenColor];
        self.intensityLabel.textColor = [UIColor greenColor];
        
        //TODO: set exp/iso
        int bfExposureDuration = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraExposureDurationBF"];
        int bfISOSpeed = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraISOSpeedBF"];
        [[TBScopeCamera sharedCamera] setExposureDuration:bfExposureDuration ISOSpeed:bfISOSpeed];
        
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:intensity];

        [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeSharpness];
        
        [self.bfButton setTitle:NSLocalizedString(@"BF On",nil) forState:UIControlStateNormal];
        [self.bfButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    }
    else
    {
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
        [self.bfButton setTitle:NSLocalizedString(@"BF Off",nil) forState:UIControlStateNormal];
        [self.bfButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
        self.intensitySlider.hidden = YES;
        self.intensityLabel.hidden = YES;
        
    }

}

- (void) toggleFL:(BOOL)on
{
    if (on)
    {
        int intensity = [[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanFluorescentIntensity"];
        self.intensitySlider.hidden = NO;
        self.intensityLabel.hidden = NO;
        [self.intensitySlider setValue:(float)intensity/255];
        [self.intensityLabel setText:[NSString stringWithFormat:@"%d",intensity]];
        
        self.intensitySlider.tintColor = [UIColor blueColor];
        self.intensityLabel.textColor = [UIColor blueColor];
        
        int flExposureDuration = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraExposureDurationFL"];
        int flISOSpeed = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraISOSpeedFL"];
        [[TBScopeCamera sharedCamera] setExposureDuration:flExposureDuration ISOSpeed:flISOSpeed];
        
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:intensity];
        
        [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeContrast];
        
        [self.flButton setTitle:NSLocalizedString(@"FL On",nil) forState:UIControlStateNormal];
        [self.flButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];

    }
    else
    {
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
        [self.flButton setTitle:NSLocalizedString(@"FL Off",nil) forState:UIControlStateNormal];
        [self.flButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
        self.intensitySlider.hidden = YES;
        self.intensityLabel.hidden = YES;
    }
}

- (IBAction)intensitySliderDidChange:(id)sender
{
    if (_BFOn)
    {
        int intensity = self.intensitySlider.value*255;
        [self.intensityLabel setText:[NSString stringWithFormat:@"%d",intensity]];
        //[[NSUserDefaults standardUserDefaults] setInteger:intensity forKey:@"AutoScanBFIntensity"];
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:intensity];
    }
    else if (_FLOn)
    {
        int intensity = self.intensitySlider.value*255;
        [self.intensityLabel setText:[NSString stringWithFormat:@"%d",intensity]];
        //[[NSUserDefaults standardUserDefaults] setInteger:intensity forKey:@"AutoScanFluorescentIntensity"];
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:intensity];
    }
}

-(IBAction)didPressMoveHome:(id)sender
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [[TBScopeHardware sharedHardware] waitForStage];
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZHome];
        [[TBScopeHardware sharedHardware] waitForStage];
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionHome];
        [[TBScopeHardware sharedHardware] waitForStage];
    });
}

-(IBAction)didPressMoveCenter:(id)sender
{
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [[TBScopeHardware sharedHardware] waitForStage];
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZHome];
        [[TBScopeHardware sharedHardware] waitForStage];
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionHome];
        [[TBScopeHardware sharedHardware] waitForStage];
        [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZDown];
        [[TBScopeHardware sharedHardware] waitForStage];
        
        int centerX = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"SlideCenterX"];
        int centerY = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"SlideCenterY"];
        int focusZ = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultFocusZ"];
        int stageStepInterval = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"StageStepInterval"];
        int focusStepInterval = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FocusStepInterval"];
        
        //move to center
        [[TBScopeHardware sharedHardware] setStepperInterval:stageStepInterval];
        [[TBScopeHardware sharedHardware] moveToX:centerX Y:centerY Z:-1];
        [[TBScopeHardware sharedHardware] waitForStage];
        [[TBScopeHardware sharedHardware] setStepperInterval:focusStepInterval];
        [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:focusZ];
        [[TBScopeHardware sharedHardware] waitForStage];

    });
}

-(IBAction)didPressSetCenter:(id)sender
{
    
    int centerX = (int)[[TBScopeHardware sharedHardware] xPosition];
    int centerY = (int)[[TBScopeHardware sharedHardware] yPosition];
    int focusZ = (int)[[TBScopeHardware sharedHardware] zPosition];
    
    [[NSUserDefaults standardUserDefaults] setInteger:centerX forKey:@"SlideCenterX"];
    [[NSUserDefaults standardUserDefaults] setInteger:centerY forKey:@"SlideCenterY"];
    [[NSUserDefaults standardUserDefaults] setInteger:focusZ forKey:@"DefaultFocusZ"];
    
    [TBScopeData CSLog:[NSString stringWithFormat:@"Set new slide center position to (%d, %d, %d)",centerX,centerY,focusZ] inCategory:@"CALIBRATION"];
}


- (IBAction)didTouchUpStageButton:(id)sender
{
    UIButton* buttonPressed = (UIButton*)sender;

    static BOOL AEOn=YES;
    static BOOL AFOn=YES;
    
    if (buttonPressed.tag==7) //BF
    {
        if (_FLOn) {
            [self toggleFL:NO];
            _FLOn = NO;
        }

        _BFOn = !_BFOn;
        [self toggleBF:_BFOn];
        
    }
    else if (buttonPressed.tag==8) //FL
    {
        if (_BFOn) {
            [self toggleBF:NO];
            _BFOn = NO;
        }
        _FLOn = !_FLOn;
        [self toggleFL:_FLOn];
    }
    else if (buttonPressed.tag==9) //AE
    {
        if (AEOn)
        {
            [[TBScopeCamera sharedCamera] setExposureLock:YES];
            [buttonPressed setTitle:NSLocalizedString(@"AE Off",nil) forState:UIControlStateNormal];
            [buttonPressed setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
        else
        {
            [[TBScopeCamera sharedCamera] setExposureLock:NO];
            [buttonPressed setTitle:NSLocalizedString(@"AE On",nil) forState:UIControlStateNormal];
            [buttonPressed setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
        }
        AEOn = !AEOn;
    }
    else if (buttonPressed.tag==10) //AF
    {
        if (AFOn)
        {
            [[TBScopeCamera sharedCamera] setFocusLock:YES];
            [buttonPressed setTitle:NSLocalizedString(@"AF Off",nil) forState:UIControlStateNormal];
            [buttonPressed setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
        else
        {
            [[TBScopeCamera sharedCamera] setFocusLock:NO];
            [buttonPressed setTitle:NSLocalizedString(@"AF On",nil) forState:UIControlStateNormal];
            [buttonPressed setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
        }
        AFOn = !AFOn;
    }
    else //stage control button
    {
        [holdTimer invalidate];
        holdTimer = nil;
        [[TBScopeHardware sharedHardware] disableMotors];
    }
}

//this function gets called whenever a stage move has completed, regardless of what initiated the move
- (void) tbScopeStageMoveDidCompleteWithXLimit:(BOOL)xLimit YLimit:(BOOL)yLimit ZLimit:(BOOL)zLimit;
{
    NSLog(@"move completed x=%d y=%d z=%d",xLimit,yLimit,zLimit);
}

//timer function
-(void) moveStage:(NSTimer *)timer
{

        if (self.currentSpeed==CSStageSpeedSlow)
            [[TBScopeHardware sharedHardware] moveStageWithDirection:self.currentDirection Steps:20 StopOnLimit:YES DisableAfter:YES];
        else if (self.currentSpeed==CSStageSpeedFast)
            [[TBScopeHardware sharedHardware] moveStageWithDirection:self.currentDirection Steps:100 StopOnLimit:YES DisableAfter:YES];
    
}

- (void) didReceiveMemoryWarning
{
    [TBScopeData CSLog:@"CaptureViewController received memory warning" inCategory:@"ERROR"];
}

- (void)didPressFastSlow:(id)sender
{
    if (self.currentSpeed==CSStageSpeedFast)
    {
        self.currentSpeed = CSStageSpeedSlow;
        [self.fastSlowButton setTitle:NSLocalizedString(@"Slow",0) forState:UIControlStateNormal];
        [self.fastSlowButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    else
    {
        self.currentSpeed = CSStageSpeedFast;
        [self.fastSlowButton setTitle:NSLocalizedString(@"Fast",0) forState:UIControlStateNormal];
        [self.fastSlowButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
        
    }
}

- (IBAction)didPressAutoFocus:(id)sender;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [[TBScopeFocusManager sharedFocusManager] autoFocus];
    });
}

- (IBAction)didPressAutoScan:(id)sender;
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [self autoscanWithCols:[[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanCols"]
                          Rows:[[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanRows"]
            stepsBetweenFields:[[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanStepsBetweenFields"]
                 focusInterval:[[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanFocusInterval"]
                   bfIntensity:[[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanBFIntensity"]
                   flIntensity:[[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanFluorescentIntensity"]];
    });
}

- (IBAction)didPressAutoTest:(id)sender
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [self takeCalibrationImages];
    });
}

- (void) manualFocus
{
    [self manualFocus:NSLocalizedString(@"Please Re-focus", nil)];
}

- (void) manualFocus:(NSString*)prompt
{
    
    dispatch_async(dispatch_get_main_queue(), ^(void){
        self.scanStatusLabel.text = prompt;
        self.manualScanFocusDown.hidden = NO;
        self.manualScanFocusUp.hidden = NO;
        self.manualScanFocusOk.hidden = NO;
        self.upButton.hidden = NO;
        self.downButton.hidden = NO;
        self.leftButton.hidden = NO;
        self.rightButton.hidden = NO;
        

    });
    
    [TBScopeData CSLog:@"Manual focus controls presented." inCategory:@"CAPTURE"];
    
    
    [self playSound:@"please_refocus"];
    
    self.currentSpeed = CSStageSpeedFast; //CSStageSpeedSlow;
    
    _isWaitingForFocusConfirmation = YES;
    while (_isWaitingForFocusConfirmation && !_isAborting)
        [NSThread sleepForTimeInterval:0.1];
    
    [TBScopeData CSLog:[NSString stringWithFormat:@"Manual re-focus completed with coordinates: (%d, %d, %d)",
                        [[TBScopeHardware sharedHardware] xPosition],
                        [[TBScopeHardware sharedHardware] yPosition],
                        [[TBScopeHardware sharedHardware] zPosition]]
            inCategory:@"CALIBRATION"];
    
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
    [NSThread sleepForTimeInterval:0.1];
    
    dispatch_async(dispatch_get_main_queue(), ^(void){

        self.manualScanFocusDown.hidden = YES;
        self.manualScanFocusUp.hidden = YES;
        self.manualScanFocusOk.hidden = YES;
        self.upButton.hidden = YES;
        self.downButton.hidden = YES;
        self.leftButton.hidden = YES;
        self.rightButton.hidden = YES;
    });
}

//TODO: these input parameters don't really need to be here (we can pull it all out of core data)
- (void) autoscanWithCols:(int)numCols
                     Rows:(int)numRows
       stepsBetweenFields:(long)stepsBetween
            focusInterval:(int)focusInterval
              bfIntensity:(int)bfIntensity
              flIntensity:(int)flIntensity
{
    int maxAFFailures = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"MaxAFFailures"];
    
    //x/y center position and default focus position
    int centerX = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"SlideCenterX"];
    int centerY = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"SlideCenterY"];
    int focusZ = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultFocusZ"];
    
    //get exposure and ISO settings
    int bfExposureDuration = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraExposureDurationBF"];
    int bfISOSpeed = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraISOSpeedBF"];
    int flExposureDuration = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraExposureDurationFL"];
    int flISOSpeed = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraISOSpeedFL"];
    
    //speed parameters
    int stageStepInterval = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"StageStepInterval"];
    int focusStepInterval = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FocusStepInterval"];
    float stageSettlingTime = [[NSUserDefaults standardUserDefaults] floatForKey:@"StageSettlingTime"];

    //backlash compensation on serpentine turnaround
    int backlashSteps = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"StageBacklashSteps"];
    
    [TBScopeData CSLog:@"Autoscanning..." inCategory:@"CAPTURE"];
    
    //setup UI
    dispatch_async(dispatch_get_main_queue(), ^(void){
        self.controlPanelView.hidden = YES;
        self.leftButton.hidden = YES;
        self.rightButton.hidden = YES;
        self.downButton.hidden = YES;
        self.upButton.hidden = YES;
        self.intensitySlider.hidden = YES;
        self.intensityLabel.hidden = YES;
        self.autoFocusButton.hidden = YES;
        self.autoScanButton.hidden = YES;
        self.scanStatusLabel.hidden = NO;
        self.abortButton.hidden = NO;
        self.refocusButton.hidden = NO;
        
        self.autoScanProgressBar.hidden = NO;
        self.autoScanProgressBar.progress = 0;
        self.scanStatusLabel.text = NSLocalizedString(@"Moving to slide center...", nil);
            
        [[self navigationController] setNavigationBarHidden:YES animated:YES];
    });
    
    //starting conditions
    int autoFocusFailCount = maxAFFailures; //this will ensure that a BF focus gets triggered at the beginning
    int fieldsSinceLastFocus = focusInterval; //this will ensure that a FL focus gets triggered at the beginning
    int boundaryFieldCount = 0;
    int emptyFieldCount = 0;
    int acquiredImageCount = 0;

    //set exposure/ISO
    [[TBScopeCamera sharedCamera] setExposureDuration:bfExposureDuration ISOSpeed:bfISOSpeed];

    //turn off lights
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
    
    [NSThread sleepForTimeInterval:0.1];
    
    [self playSound:@"scanning_started"];
    
    //home stage and move objective to "down" position
    [[TBScopeHardware sharedHardware] waitForStage];
    [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZHome];
    [[TBScopeHardware sharedHardware] waitForStage];
    [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionHome];
    [[TBScopeHardware sharedHardware] waitForStage];
    [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZDown];
    [[TBScopeHardware sharedHardware] waitForStage];
    
    //check if abort button pressed
    if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
    
    [NSThread sleepForTimeInterval:0.1];
    
    //set stage speed and move to center
    [[TBScopeHardware sharedHardware] setStepperInterval:stageStepInterval];
    [[TBScopeHardware sharedHardware] moveToX:centerX Y:centerY Z:-1];
    [[TBScopeHardware sharedHardware] waitForStage];
    [[TBScopeHardware sharedHardware] setStepperInterval:focusStepInterval];
    [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:focusZ];
    [[TBScopeHardware sharedHardware] waitForStage];
    
    //check if abort button pressed
    if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
    
    [NSThread sleepForTimeInterval:0.1];
    
    //move to first position in grid
    //backup in both X and Y by half the row/col distance
    long xSteps = (numCols/2)*stepsBetween;
    long ySteps = (numRows/2)*stepsBetween;
    [[TBScopeHardware sharedHardware] setStepperInterval:stageStepInterval];
    [[TBScopeHardware sharedHardware] moveStageWithDirection:CSStageDirectionRight Steps:ySteps StopOnLimit:YES DisableAfter:YES];
    [[TBScopeHardware sharedHardware] waitForStage];
    [[TBScopeHardware sharedHardware] moveStageWithDirection:CSStageDirectionUp Steps:xSteps StopOnLimit:YES DisableAfter:YES];
    [[TBScopeHardware sharedHardware] waitForStage];
    
    //check if abort button pressed
    if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
    
    [NSThread sleepForTimeInterval:0.1];
    
    dispatch_async(dispatch_get_main_queue(), ^(void){
        self.scanStatusLabel.text = NSLocalizedString(@"Initial Focusing...", nil);
    });

    //reset focus manager
    [[TBScopeFocusManager sharedFocusManager] clearLastGoodPositionAndMetric];
    
    //check if abort button pressed
    if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
    
    int yDir;
    
    //x iterator
    for (int i=0; i<numCols; i++) {
        
        //figure out which way y is moving
        if ((i%2)==0) //even, move down
            yDir = CSStageDirectionLeft;
        else //odd, move up
            yDir = CSStageDirectionRight;
        
        //backlash compensation
        [[TBScopeHardware sharedHardware] setStepperInterval:stageStepInterval];
        [[TBScopeHardware sharedHardware] moveStageWithDirection:yDir
                                                           Steps:backlashSteps
                                                     StopOnLimit:YES
                                                    DisableAfter:YES];
        [[TBScopeHardware sharedHardware] waitForStage];
        [NSThread sleepForTimeInterval:stageSettlingTime];
        
        //y iterator
        for (int j=0; j<numRows; j++) {
            int fieldNum = i*numRows + j;
            [TBScopeData CSLog:[NSString stringWithFormat:@"Scanning field %d",fieldNum] inCategory:@"CAPTURE"];
            
            //check if abort button pressed
            if (_isAborting) {
                dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];});
                return; }
            
            //focus in BF if this is the initial focus or if focus failures is >maxAFFailures
            if (autoFocusFailCount>=maxAFFailures)
            {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    self.scanStatusLabel.text = NSLocalizedString(@"Focusing...", nil);});
                
                [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
                [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:bfIntensity];
                [[TBScopeCamera sharedCamera] setExposureDuration:bfExposureDuration ISOSpeed:bfISOSpeed];
                [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeSharpness];
                
                [NSThread sleepForTimeInterval:0.1];
                
                TBScopeFocusManagerResult focusResult;
                for (int i=0; i<NUM_FOCUS_REPOSITIONING_ATTEMPTS; i++) {
                    [[TBScopeHardware sharedHardware] setStepperInterval:focusStepInterval];
                    focusResult = [[TBScopeFocusManager sharedFocusManager] autoFocus];
                    if (focusResult!=TBScopeFocusManagerResultSuccess) {
                        [[TBScopeHardware sharedHardware] setStepperInterval:stageStepInterval];
                        [[TBScopeHardware sharedHardware] moveStageWithDirection:yDir
                                                                           Steps:FOCUS_REPOSITIONING_STEPS
                                                                     StopOnLimit:YES
                                                                    DisableAfter:YES];
                        [[TBScopeHardware sharedHardware] waitForStage];
                        [NSThread sleepForTimeInterval:stageSettlingTime];
                    }
                    else
                        break;
                }
                
                if (focusResult == TBScopeFocusManagerResultFailure) {
                    [self manualFocus]; //allow them to refocus in BF at the beginning
                    [[TBScopeFocusManager sharedFocusManager] setLastGoodPosition:[[TBScopeHardware sharedHardware] zPosition]];
                }
                //switch to fluorescence
                [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:flIntensity];
                [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
                [[TBScopeCamera sharedCamera] setExposureDuration:flExposureDuration ISOSpeed:flISOSpeed];
                [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeContrast];
                
                [NSThread sleepForTimeInterval:0.5];
                
                autoFocusFailCount = 0;
            }
            
            
            //check if abort button pressed
            if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
            
            // remaining focusing operations will be done with contrast (for fluorescence)
            [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeContrast];

            // focus in fluorescence (each N frames)
            fieldsSinceLastFocus++;
            if (fieldsSinceLastFocus>=focusInterval) {
                if (![[TBScopeCamera sharedCamera] currentImageQuality].isEmpty) {

                    TBScopeFocusManagerResult focusResult;
                    for (int i=0; i<NUM_FOCUS_REPOSITIONING_ATTEMPTS; i++) {
                        [[TBScopeHardware sharedHardware] setStepperInterval:focusStepInterval];
                        focusResult = [[TBScopeFocusManager sharedFocusManager] autoFocus];
                        if (focusResult!=TBScopeFocusManagerResultSuccess) {
                            [[TBScopeHardware sharedHardware] setStepperInterval:stageStepInterval];
                            [[TBScopeHardware sharedHardware] moveStageWithDirection:yDir
                                                                               Steps:FOCUS_REPOSITIONING_STEPS
                                                                         StopOnLimit:YES
                                                                        DisableAfter:YES];
                            [[TBScopeHardware sharedHardware] waitForStage];
                            [NSThread sleepForTimeInterval:stageSettlingTime];
                        }
                        else
                            break;
                        
                    }

                    
                    if (focusResult != TBScopeFocusManagerResultSuccess) {
                        autoFocusFailCount++;
                    } else {
                        autoFocusFailCount = 0;
                        fieldsSinceLastFocus = 0;
                    }
                }
            }
            
            //gives the user the option to intervene...
            if (_didPressManualFocus) {
                self.refocusButton.hidden = YES;
                
                [self manualFocus];
                [[TBScopeFocusManager sharedFocusManager] setLastGoodPosition:[[TBScopeHardware sharedHardware] zPosition]];
                self.refocusButton.hidden = NO;
                _didPressManualFocus = NO;
                autoFocusFailCount = 0;
                fieldsSinceLastFocus = 0;
            }
            
            //check image content score, and take an image if it's not empty
            
             if ([[TBScopeCamera sharedCamera] currentImageQuality].isEmpty) {
                 emptyFieldCount++;
                 [self.currentSlide.managedObjectContext performBlockAndWait:^{
                     self.currentSlide.numSkippedEmptyFields++;
                 }];
                 [TBScopeData CSLog:@"Skipping image capture; image is empty." inCategory:@"CAPTURE"];
             }
             //else if (iq.isBoundary) {
             // boundaryFieldCount++;
             // [TBScopeData CSLog:@"Skipping image capture; image contains boundary." inCategory:@"CAPTURE"];
             // }
             else {
                 [self didPressCapture:nil];
                 [NSThread sleepForTimeInterval:0.1]; //I'm not sure if this is required. Used to be 0.5.
                 acquiredImageCount++;
             }
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                self.scanStatusLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Acquired Images: %d, Fields Remaining: %d", nil),acquiredImageCount,((numRows*numCols)-acquiredImageCount-boundaryFieldCount-emptyFieldCount)];
                self.autoScanProgressBar.progress = (float)fieldNum/(numRows*numCols);
            });
            
            //move stage in y
            [[TBScopeHardware sharedHardware] setStepperInterval:stageStepInterval];
            [[TBScopeHardware sharedHardware] moveStageWithDirection:yDir
                                                               Steps:stepsBetween
                                                         StopOnLimit:YES
                                                        DisableAfter:YES];
            [[TBScopeHardware sharedHardware] waitForStage];
            [NSThread sleepForTimeInterval:stageSettlingTime];

        }
        
        //move stage in x (next column)
        [[TBScopeHardware sharedHardware] setStepperInterval:stageStepInterval];
        [[TBScopeHardware sharedHardware] moveStageWithDirection:CSStageDirectionDown
                                                           Steps:stepsBetween
                                                     StopOnLimit:YES
                                                    DisableAfter:YES];
        [[TBScopeHardware sharedHardware] waitForStage];

    }
    
    //turn off BF and FL
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
    
    [TBScopeData CSLog:[NSString stringWithFormat:@"Scan completed with %d acquired images, %d skipped empty fields, %d skipped boundary fields, and %d failed focus attempts",acquiredImageCount,emptyFieldCount,boundaryFieldCount,autoFocusFailCount] inCategory:@"CAPTURE"];
     
    [self playSound:@"scanning_complete"];
    
    dispatch_async(dispatch_get_main_queue(), ^(void){
        self.scanStatusLabel.text = NSLocalizedString(@"Acquisition complete...", nil);
        
        //do analysis
        [self performSegueWithIdentifier:@"AnalysisSegue" sender:self];
        
        //reenable buttons
        self.controlPanelView.hidden = NO;
        self.leftButton.hidden = NO;
        self.rightButton.hidden = NO;
        self.downButton.hidden = NO;
        self.upButton.hidden = NO;
        self.autoFocusButton.hidden = NO;
        self.autoScanButton.hidden = NO;
        self.scanStatusLabel.hidden = YES;
        self.abortButton.hidden = YES;
        self.refocusButton.hidden = YES;
        self.autoScanProgressBar.hidden = YES;

    });
    
}

//TODO: much of this code is copied from autoScan above. Would be a good idea to refactor these once we see where the common denominators are
-(void) takeCalibrationImages
{
    [TBScopeData CSLog:@"Beginning auto calibration routine." inCategory:@"CALIBRATION"];
    
    //setup UI
    dispatch_async(dispatch_get_main_queue(), ^(void){
        self.controlPanelView.hidden = YES;
        self.leftButton.hidden = YES;
        self.rightButton.hidden = YES;
        self.downButton.hidden = YES;
        self.upButton.hidden = YES;
        self.intensitySlider.hidden = YES;
        self.intensityLabel.hidden = YES;
        self.autoFocusButton.hidden = YES;
        self.autoScanButton.hidden = YES;
        self.scanStatusLabel.hidden = NO;
        self.abortButton.hidden = NO;
        self.refocusButton.hidden = YES;
        self.fineCoarseSelector.hidden = NO;
        self.autoScanProgressBar.hidden = NO;
        self.autoScanProgressBar.progress = 0;
        self.calibrationTypeSelector.hidden = NO;
        self.scanStatusLabel.text = NSLocalizedString(@"Beginning auto test procedure...", nil);
        
        [[self navigationController] setNavigationBarHidden:YES animated:YES];
    });
    
    //LED intensity
    int bfIntensity = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanBFIntensity"];
    int flIntensitySmears = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanFluorescentIntensity"];
    int flIntensityCalibration = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CalibrationFluorescentIntensity"];
    
    //x/y center position and default focus position
    int centerX = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"SlideCenterX"];
    int centerY = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"SlideCenterY"];
    int focusZ = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultFocusZ"];
    
    //get exposure and ISO settings
    int bfExposureDuration = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraExposureDurationBF"];
    int bfISOSpeed = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraISOSpeedBF"];
    int flExposureDuration = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraExposureDurationFL"];
    int flISOSpeed = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraISOSpeedFL"];
    
    //speed parameters
    int stageStepInterval = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"StageStepInterval"];
    int focusStepInterval = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"FocusStepInterval"];
    float stageSettlingTime = [[NSUserDefaults standardUserDefaults] floatForKey:@"StageSettlingTime"];
    float focusSettlingTime = [[NSUserDefaults standardUserDefaults] floatForKey:@"FocusSettlingTime"];
    
    
    //set exposure/ISO
    [[TBScopeCamera sharedCamera] setExposureDuration:bfExposureDuration ISOSpeed:bfISOSpeed];
    
    //turn off lights
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
    
    [NSThread sleepForTimeInterval:0.1];
    
    //home stage and move objective to "down" position
    [[TBScopeHardware sharedHardware] waitForStage];
    [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZHome];
    [[TBScopeHardware sharedHardware] waitForStage];
    [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionHome];
    [[TBScopeHardware sharedHardware] waitForStage];
    [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZDown];
    [[TBScopeHardware sharedHardware] waitForStage];
    
    //check if abort button pressed
    if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
    
    [NSThread sleepForTimeInterval:0.1];
    
    //set stage speed and move to center
    [[TBScopeHardware sharedHardware] setStepperInterval:stageStepInterval];
    [[TBScopeHardware sharedHardware] moveToX:centerX Y:centerY Z:-1];
    [[TBScopeHardware sharedHardware] waitForStage];
    [[TBScopeHardware sharedHardware] setStepperInterval:focusStepInterval];
    [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:focusZ];
    [[TBScopeHardware sharedHardware] waitForStage];
    
    //check if abort button pressed
    if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
    
    [NSThread sleepForTimeInterval:0.1];
    

    for (int fieldNum = 0; fieldNum<5; fieldNum++) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            self.autoScanProgressBar.progress = (float)fieldNum/5.0;
        });
        
        if (self.calibrationTypeSelector.selectedSegmentIndex==0) {
            //low intensity fluorescence fluorescence
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:flIntensityCalibration];
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
            [[TBScopeCamera sharedCamera] setExposureDuration:flExposureDuration ISOSpeed:flISOSpeed];
            [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeContrast];
        }
        else if (self.calibrationTypeSelector.selectedSegmentIndex==1) {
            //brightfield
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:bfIntensity];
            [[TBScopeCamera sharedCamera] setExposureDuration:bfExposureDuration ISOSpeed:bfISOSpeed];
            [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeSharpness];
        }
        else {
            //high intensity fluorescence fluorescence
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:flIntensitySmears];
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
            [[TBScopeCamera sharedCamera] setExposureDuration:flExposureDuration ISOSpeed:flISOSpeed];
            [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeContrast];
        }
        
        [NSThread sleepForTimeInterval:0.5];
        
        //have the user manually focus the scope
        if (self.calibrationTypeSelector.selectedSegmentIndex==0) {
            [self manualFocus:NSLocalizedString(@"Move the scope to a uniform field of beads and focus.", nil)];
        }
        else {
            [self manualFocus:NSLocalizedString(@"Move the scope to a new area of the smear and focus.", nil)];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            self.scanStatusLabel.text = NSLocalizedString(@"Please wait...", nil);

        });
        
        if (self.calibrationTypeSelector.selectedSegmentIndex==0) {
            //snap a fluorescent picture at low brightness
            [self didPressCapture:nil];
            [NSThread sleepForTimeInterval:0.5];
            
            //snap a fluorescent picture at full (smear) brightness
            //this is useful for gauging background
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:flIntensitySmears];
            [NSThread sleepForTimeInterval:0.5];
            
            [self didPressCapture:nil];
            [NSThread sleepForTimeInterval:0.5];
            
            //switch to brightfield
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:bfIntensity];
            [[TBScopeCamera sharedCamera] setExposureDuration:bfExposureDuration ISOSpeed:bfISOSpeed];
            [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeSharpness];
            
            [NSThread sleepForTimeInterval:0.5];
            
            //check if abort button pressed
            if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
            
            //snap a BF picture
            [self didPressCapture:nil];
            [NSThread sleepForTimeInterval:0.5];
            
        }

        if (self.calibrationTypeSelector.selectedSegmentIndex==0) {
            //switch back to low brightness fluorescence
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:flIntensityCalibration];
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
            [[TBScopeCamera sharedCamera] setExposureDuration:flExposureDuration ISOSpeed:flISOSpeed];
            [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeContrast];
        }
        else if (self.calibrationTypeSelector.selectedSegmentIndex==1) {
            //switch back to low brightness fluorescence
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:bfIntensity];
            [[TBScopeCamera sharedCamera] setExposureDuration:bfExposureDuration ISOSpeed:bfISOSpeed];
            [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeSharpness];
        }
        else {
            //switch back to low brightness fluorescence
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:flIntensitySmears];
            [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
            [[TBScopeCamera sharedCamera] setExposureDuration:flExposureDuration ISOSpeed:flISOSpeed];
            [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeContrast];
        }
        
        [NSThread sleepForTimeInterval:0.5];
        
        //check if abort button pressed
        if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
    
        //get z stack size and step size
        int minSlice;
        int maxSlice;
        int zStep;
        if (self.fineCoarseSelector.selectedSegmentIndex==0) { //fine (default)
            minSlice = -1000;
            maxSlice = 1000;
            zStep = 200;
        }
        else
        {
            minSlice = - [[NSUserDefaults standardUserDefaults] integerForKey:@"FocusBroadSweepRange"] / 2 ;
            maxSlice = [[NSUserDefaults standardUserDefaults] integerForKey:@"FocusBroadSweepRange"] / 2;
            zStep = [[NSUserDefaults standardUserDefaults] integerForKey:@"FocusBroadSweepStepSize"];
        }
        
        //sweep through an 11-slice z stack at reduced LED intensity and take pictures at each slice
        int manualFocusPosition = [[TBScopeHardware sharedHardware] zPosition];
        [[TBScopeHardware sharedHardware] setStepperInterval:focusStepInterval];
        for (int i=minSlice; i<=maxSlice; i+=zStep) {
            [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:(manualFocusPosition+i)];
            [[TBScopeHardware sharedHardware] waitForStage];
            [NSThread sleepForTimeInterval:stageSettlingTime];
            
            [self didPressCapture:nil];
            [NSThread sleepForTimeInterval:0.5];
            
            //check if abort button pressed
            if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
        }
        
        //move back to manual focus position
        [[TBScopeHardware sharedHardware] moveToX:-1 Y:-1 Z:manualFocusPosition];
        [[TBScopeHardware sharedHardware] waitForStage];
        [NSThread sleepForTimeInterval:stageSettlingTime];
        
        //check if abort button pressed
        if (_isAborting) { dispatch_async(dispatch_get_main_queue(), ^(void){[self abortCapture];}); return; }
        
    }

    //turn off LEDs
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
    [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
    
    
    //restore UI
    dispatch_async(dispatch_get_main_queue(), ^(void){
        self.controlPanelView.hidden = NO;
        self.leftButton.hidden = NO;
        self.rightButton.hidden = NO;
        self.downButton.hidden = NO;
        self.upButton.hidden = NO;
        self.intensitySlider.hidden = YES;
        self.intensityLabel.hidden = YES;
        self.autoFocusButton.hidden = NO;
        self.autoScanButton.hidden = NO;
        self.scanStatusLabel.hidden = YES;
        self.abortButton.hidden = YES;
        self.autoScanProgressBar.hidden = YES;
        self.fineCoarseSelector.hidden = YES;
        self.calibrationTypeSelector.hidden = YES;
        [[self navigationController] setNavigationBarHidden:NO animated:YES];
    });
    
}

-(IBAction)didChangeCalibrationType:(id)sender
{
    
    int bfIntensity = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanBFIntensity"];
    int flIntensitySmears = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"AutoScanFluorescentIntensity"];
    int flIntensityCalibration = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CalibrationFluorescentIntensity"];

    //get exposure and ISO settings
    int bfExposureDuration = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraExposureDurationBF"];
    int bfISOSpeed = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraISOSpeedBF"];
    int flExposureDuration = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraExposureDurationFL"];
    int flISOSpeed = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"CameraISOSpeedFL"];
    
    if (self.calibrationTypeSelector.selectedSegmentIndex==0) {
        //low brightness fluorescence
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:flIntensityCalibration];
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
        [[TBScopeCamera sharedCamera] setExposureDuration:flExposureDuration ISOSpeed:flISOSpeed];
        [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeContrast];
    }
    else if (self.calibrationTypeSelector.selectedSegmentIndex==1) {
        //BF
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:0];
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:bfIntensity];
        [[TBScopeCamera sharedCamera] setExposureDuration:bfExposureDuration ISOSpeed:bfISOSpeed];
        [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeSharpness];
    }
    else {
        //Regular FL for smears
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDFluorescent Level:flIntensitySmears];
        [[TBScopeHardware sharedHardware] setMicroscopeLED:CSLEDBrightfield Level:0];
        [[TBScopeCamera sharedCamera] setExposureDuration:flExposureDuration ISOSpeed:flISOSpeed];
        [[TBScopeCamera sharedCamera] setFocusMode:TBScopeCameraFocusModeContrast];
    }
}

-(void) playSound:(NSString*)sound_file
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        NSURL* url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:sound_file ofType:@"mp3"]];
        _avPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:NULL];
        [_avPlayer setVolume:1.0];
        [_avPlayer play];
        while ([_avPlayer isPlaying]) {};
    });
}
@end
