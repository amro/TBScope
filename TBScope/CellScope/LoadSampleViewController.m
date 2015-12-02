//
//  LoadSampleViewController.m
//  TBScope
//
//  Created by Frankie Myers on 11/10/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "LoadSampleViewController.h"

@implementation LoadSampleViewController

@synthesize currentSlide,moviePlayer,videoView;

- (void) viewWillAppear:(BOOL)animated
{
    //localization
    self.navigationItem.rightBarButtonItem.title = NSLocalizedString(@"Next", nil);
    self.navigationItem.title = NSLocalizedString(@"Load Sample Slide", nil);
    self.promptLabel.text = NSLocalizedString(@"Load the slide as shown below:", nil);
    [self.directionsLabel setText:NSLocalizedString(@"Wait for loading tray to come to a stop before inserting slide. Insert slide with sputum side up and gently push into machine. Click next. Slide will automatically load into position for image capture.", nil)];
    
    //next button is disabled until slide is inserted
    //self.navigationItem.rightBarButtonItem.enabled = NO;
    
    [TBScopeData CSLog:@"Load slide screen presented" inCategory:@"USER"];
}

- (void) viewDidAppear:(BOOL)animated
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DoAutoLoadSlide"]  && [self isMovingToParentViewController])
    {
        [self performSegueWithIdentifier:@"ScanSlideSegue" sender:self];
    }
    else
    {
        NSString *url   =   [[NSBundle mainBundle] pathForResource:@"slideloading" ofType:@"mp4"];
        
        moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL fileURLWithPath:url]];
        
        moviePlayer.fullscreen = NO;
        moviePlayer.allowsAirPlay = NO;
        moviePlayer.controlStyle = MPMovieControlStyleNone;
        moviePlayer.scalingMode = MPMovieScalingModeAspectFill;
        moviePlayer.repeatMode = MPMovieRepeatModeOne;
        
        [moviePlayer.view setFrame:videoView.bounds];
        [videoView addSubview:moviePlayer.view];
        
        [moviePlayer play];

        //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //home z
            [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionZHome];
            
            //extend the tray
            [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionLoading];
            
            //draw tray in
            [[TBScopeHardware sharedHardware] moveToPosition:CSStagePositionHome];

            //[[TBScopeHardware sharedHardware] waitForStage];
        
            //next button is disabled until slide is inserted
            //Note: this doesn't work
        //    dispatch_async(dispatch_get_main_queue(), ^{
        //        self.navigationItem.rightBarButtonItem.enabled = YES;
        //    });
        //});
        

    }


}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    CaptureViewController* cvc = (CaptureViewController*)[segue destinationViewController];
    cvc.currentSlide = self.currentSlide;
}

@end
