//
//  LogViewController.m
//  TBScope
//
//  Created by Frankie Myers on 10/10/2014.
//  Copyright (c) 2014 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "LogViewController.h"

@interface LogViewController ()

@end

@implementation LogViewController


- (void)viewWillAppear:(BOOL)animated
{
    //I'm not sure why I can't get this view to appear in the top navigation bar. It seems that when a tab bar is present, nothing shows up in the top
    //self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.filterBarView];
    
    self.tabBarController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.filterBarView];
    
    [self.analysisFilterButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [self.captureFilterButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [self.calibrationFilterButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [self.syncFilterButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [self.dataFilterButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [self.systemFilterButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [self.errorFilterButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    [self.userFilterButton setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    
    //setup date/time formatters
    self.dateFormatter = [[NSDateFormatter alloc] init];
    [self.dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [self.dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    self.timeFormatter = [[NSDateFormatter alloc] init];
    [self.timeFormatter setDateStyle:NSDateFormatterNoStyle];
    [self.timeFormatter setTimeStyle:NSDateFormatterMediumStyle];
    

    [self reloadData];
}

- (void)reloadData
{
    
    NSMutableString* predicateString = [NSMutableString stringWithString:@""];

    if (self.captureFilterButton.titleLabel.textColor == [UIColor yellowColor])
        [predicateString appendString:@"(category == 'CAPTURE') ||"];
    if (self.dataFilterButton.titleLabel.textColor == [UIColor yellowColor])
        [predicateString appendString:@"(category == 'DATA') ||"];
    if (self.userFilterButton.titleLabel.textColor == [UIColor yellowColor])
        [predicateString appendString:@"(category == 'USER') ||"];
    if (self.calibrationFilterButton.titleLabel.textColor == [UIColor yellowColor])
        [predicateString appendString:@"(category == 'CALIBRATION') ||"];
    if (self.syncFilterButton.titleLabel.textColor == [UIColor yellowColor])
        [predicateString appendString:@"(category == 'SYNC') ||"];
    if (self.systemFilterButton.titleLabel.textColor == [UIColor yellowColor])
        [predicateString appendString:@"(category == 'SYSTEM') ||"];
    if (self.analysisFilterButton.titleLabel.textColor == [UIColor yellowColor])
        [predicateString appendString:@"(category == 'ANALYSIS') ||"];
    if (self.errorFilterButton.titleLabel.textColor == [UIColor yellowColor])
        [predicateString appendString:@"(category == 'ERROR') ||"];
    
    [predicateString appendString:@"(category == '')"];
    
    NSLog(predicateString);
    
    NSPredicate* pred = [NSPredicate predicateWithFormat:predicateString];
    
    self.logData  = [CoreDataHelper searchObjectsForEntity:@"Logs" withPredicate:pred andSortKey:@"date" andSortAscending:NO andContext:[[TBScopeData sharedData] managedObjectContext]];
    [[self tableView] reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.logData count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    LogEntryCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    // Get the core data object we need to use to populate this table cell
    Logs* currentLogEntry = [self.logData objectAtIndex:indexPath.row];
   
    
    // Fill in the cell contents
    NSString* dateString = [self.dateFormatter stringFromDate:[TBScopeData dateFromString:currentLogEntry.date]];
    NSString* timeString = [self.timeFormatter stringFromDate:[TBScopeData dateFromString:currentLogEntry.date]];
    
    cell.categoryLabel.text = currentLogEntry.category;
    cell.messageLabel.text = currentLogEntry.entry;
    cell.dateLabel.text = dateString;
    cell.timeLabel.text = timeString;
    
    return cell;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([sender isKindOfClass:[LogEntryCell class]])
    {
        LogEntryDetailViewController* ledvc = (LogEntryDetailViewController*)[segue destinationViewController];
        NSIndexPath *indexPath = [[self tableView] indexPathForCell:sender];
        ledvc.currentLogEntry = [self.logData objectAtIndex:indexPath.row];
    }
}

- (IBAction)didPressFilterButton:(id)sender
{
    UIButton* button = (UIButton*)sender;
    if (button.titleLabel.textColor==[UIColor yellowColor]) {
        [button setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        
    }
    else
        [button setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    
    [self reloadData];
}

@end
