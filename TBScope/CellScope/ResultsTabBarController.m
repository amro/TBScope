//
//  ResultsViewController.m
//  CellScope
//
//  Created by Frankie Myers on 11/1/13.
//  Copyright (c) 2013 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "ResultsTabBarController.h"

//TODO: need to display patient/slide metadata somehow (at least from list)...maybe new tab, or maybe all on 1st tab


@implementation ResultsTabBarController

- (void)viewDidLoad
{
    [super viewDidLoad];
    

    [[self.tabBar.items objectAtIndex:0] setTitle:NSLocalizedString(@"Diagnosis", nil)];
    [[self.tabBar.items objectAtIndex:1] setTitle:NSLocalizedString(@"Follow-Up", nil)];

    // Reset slideToShow if it wasn't previously set by a prepareForSegue
    if (!self.slideToShow) {
        self.slideToShow = 0;
    }
    
    NSMutableArray* tabVCs = [[NSMutableArray alloc] init];
    
    SlideDiagnosisViewController* slideDiagnosisVC = (SlideDiagnosisViewController*)(self.viewControllers[0]);
    slideDiagnosisVC.currentExam = self.currentExam;
    [tabVCs addObject:slideDiagnosisVC];
    
    FollowUpViewController* followUpVC = (FollowUpViewController*)(self.viewControllers[1]);
    followUpVC.currentExam = self.currentExam;
    [tabVCs addObject:followUpVC];
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"TBScopeStoryboard" bundle: nil];
    
    if (self.currentExam.examSlides.count>0) {
        Slides *slide = self.currentExam.examSlides[0];
        if (slide.slideAnalysisResults || [slide hasLocalImages]) {
            ImageResultViewController *imageResultsVC1 = [storyboard instantiateViewControllerWithIdentifier:@"ImageResultViewController"];
            imageResultsVC1.currentSlide = (Slides*)self.currentExam.examSlides[0];
            imageResultsVC1.tabBarItem.title = [NSString stringWithFormat:NSLocalizedString(@"Slide %d", nil),1];
            imageResultsVC1.tabBarItem.image = [UIImage imageNamed:@"slide1icon.png"];
            [tabVCs addObject:imageResultsVC1];
        }
    }
    if (self.currentExam.examSlides.count>1) {
        Slides *slide = self.currentExam.examSlides[1];
        if (slide.slideAnalysisResults || [slide hasLocalImages]) {
            ImageResultViewController *imageResultsVC2 = [storyboard instantiateViewControllerWithIdentifier:@"ImageResultViewController"];
            imageResultsVC2.currentSlide = (Slides*)self.currentExam.examSlides[1];
            imageResultsVC2.tabBarItem.title = [NSString stringWithFormat:NSLocalizedString(@"Slide %d", nil),2];
            imageResultsVC2.tabBarItem.image = [UIImage imageNamed:@"slide2icon.png"];
            [tabVCs addObject:imageResultsVC2];
        }
    }
    if (self.currentExam.examSlides.count>2) {
        Slides *slide = self.currentExam.examSlides[2];
        if (slide.slideAnalysisResults || [slide hasLocalImages]) {
            ImageResultViewController *imageResultsVC3 = [storyboard instantiateViewControllerWithIdentifier:@"ImageResultViewController"];
            imageResultsVC3.currentSlide = (Slides*)self.currentExam.examSlides[2];
            imageResultsVC3.tabBarItem.title = [NSString stringWithFormat:NSLocalizedString(@"Slide %d", nil),3];
            imageResultsVC3.tabBarItem.image = [UIImage imageNamed:@"slide3icon.png"];
            [tabVCs addObject:imageResultsVC3];
        }
    }

    // TODO: make this an option (in some situations, we might not want them
    // to see images, in others we might not want them to see diagnosis, etc.
    self.viewControllers = tabVCs;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    UITabBarController *tbc = (UITabBarController*)self.navigationController.topViewController;
    if (self.slideToShow == 1) {
        if (self.viewControllers.count>2)
            [tbc setSelectedIndex:2];
    } else if (self.slideToShow == 2) {
        if (self.viewControllers.count>3)
            [tbc setSelectedIndex:3];
    } else if (self.slideToShow == 3) {
        if (self.viewControllers.count>4)
            [tbc setSelectedIndex:4];
    }
}


Slides* _lastSlide;
NSString* _humanRead;
int _slideNumber;

//TODO: may want to rethink/streamline this workflow in the future
-(BOOL) promptUserToConfirmDiagnosis
{
    // ensure that they confirm a positive diagnosis of the most recently scanned slide
    // this is a bit of a hack; it assumes the last slide in the deck is the one that was just scanned
    
    if (self.currentExam.examSlides.count==3) {
        _lastSlide = self.currentExam.examSlides[2];
        _humanRead = self.currentExam.examFollowUpData.slide1HumanReadResult;
        _slideNumber = 1;
    }
    else if (self.currentExam.examSlides.count==2) {
        _lastSlide = self.currentExam.examSlides[1];
        _humanRead = self.currentExam.examFollowUpData.slide2HumanReadResult;
        _slideNumber = 2;
    }
    else if (self.currentExam.examSlides.count==1) {
        _lastSlide = self.currentExam.examSlides[0];
        _humanRead = self.currentExam.examFollowUpData.slide3HumanReadResult;
        _slideNumber = 3;
    }
    else
        return YES;
    
    if (_lastSlide.slideAnalysisResults==nil)
        return YES;
    
    if ([_lastSlide.slideAnalysisResults.diagnosis isEqualToString:@"NEGATIVE"])
        return YES;
    
    if ([_lastSlide.slideAnalysisResults.diagnosis isEqualToString:@"POSITIVE"]) {
        if ([_humanRead isEqualToString:@"+"]) {
            return YES;
        }
        if ([_humanRead isEqualToString:@"-"]) { //user disagreed with positive result
            return YES;
        }
        else
        {
            //popup message box
            UIAlertView * alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Confirm Diagnosis", nil)
                                                             message:[NSString stringWithFormat:NSLocalizedString(@"CellScope has diagnosed slide %d as positive for tuberculosis. Based on your review of the images, do you agree with this diagnosis?",nil),_slideNumber]
                                                            delegate:self
                                                   cancelButtonTitle:NSLocalizedString(@"Let me review again.",nil)
                                                   otherButtonTitles:NSLocalizedString(@"No, this slide is negative.",nil),
                                                                     NSLocalizedString(@"Yes, this slide is positive.",nil),
                                   nil];
            alert.alertViewStyle = UIAlertViewStyleDefault;
            alert.tag = 1;
            [alert show];
            
            return NO;
        }
    }
    
}

//respond to message box
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag==1) //prompt for user to confirm positive diagnosis
    {
        if (buttonIndex==0) {
            return;
        }
        else if (buttonIndex==1) {
            if (_slideNumber==1)
                self.currentExam.examFollowUpData.slide1HumanReadResult = @"-";
            else if (_slideNumber==2)
                self.currentExam.examFollowUpData.slide2HumanReadResult = @"-";
            else if (_slideNumber==3)
                self.currentExam.examFollowUpData.slide3HumanReadResult = @"-";
            [[self navigationController] popToRootViewControllerAnimated:YES];
        }
        else if (buttonIndex==2) {
            if (_slideNumber==1)
                self.currentExam.examFollowUpData.slide1HumanReadResult = @"+";
            else if (_slideNumber==2)
                self.currentExam.examFollowUpData.slide2HumanReadResult = @"+";
            else if (_slideNumber==3)
                self.currentExam.examFollowUpData.slide3HumanReadResult = @"+";
            [[self navigationController] popToRootViewControllerAnimated:YES];
        }
        
    }
}


- (IBAction)done:(id)sender
{
    BOOL okToPop = [self promptUserToConfirmDiagnosis];
    

    if (okToPop)
        [[self navigationController] popToRootViewControllerAnimated:YES];
}

@end
