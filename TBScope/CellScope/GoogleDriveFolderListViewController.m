//
//  GoogleDriveFolderListViewController.m
//  TBScope
//
//  Created by Jason Ardell on 11/30/15.
//  Copyright © 2015 UC Berkeley Fletcher Lab. All rights reserved.
//

#import "GoogleDriveFolderListViewController.h"
#import "GoogleDriveService.h"
#import "TBScopeData.h"

@implementation GoogleDriveFolderListViewController

NSArray *_directoryList;
BOOL _isInsertingDirectory;
UITextField *_newDirectoryTextField;

- (void)viewDidLoad
{
    // Initialize directory list
    _directoryList = @[];
    _isInsertingDirectory = NO;
    [self fetchDirectoryList];

    // Set up the add button
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                               target:self
                                                                               action:@selector(addDirectory)];
    self.navigationItem.rightBarButtonItem = addButton;
    
    // Set up the cancel button
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                            target:self
                                                                            action:@selector(dismissModal)];
    self.navigationItem.leftBarButtonItem = cancelButton;
}

- (void)addDirectory
{
    // Add the editable directory to our list
    _isInsertingDirectory = YES;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:1 inSection:0];
    [[self tableView] insertRowsAtIndexPaths:@[indexPath]
                            withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)dismissModal
{
    UIViewController *sourceViewController = self.navigationController;
    [sourceViewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)fetchDirectoryList
{
    GoogleDriveService *gds = [[GoogleDriveService alloc] init];
    [gds listDirectories]
        .then(^(GTLDriveFileList *fileList) {
            _directoryList = [fileList items];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self tableView] reloadData];
                [[self tableView] setNeedsDisplay];
            });
        })
        .catch(^(NSError *error) {
            NSString *message = [NSString stringWithFormat:@"Unable to fetch directory list from Google Drive: %@", error.description];
            [TBScopeData CSLog:message inCategory:@"SETTINGS"];
        });
}

- (NSArray *)directories
{
    NSMutableArray *list = [NSMutableArray arrayWithArray:_directoryList];

    // Add the root directory as row 0
    GTLDriveFile *rootDirectory = [GTLDriveFile object];
    rootDirectory.identifier = nil;
    rootDirectory.title = @"(root directory)";
    [list insertObject:rootDirectory atIndex:0];

    // Add the "new" directory as row 1 if we're adding
    if (_isInsertingDirectory) {
        GTLDriveFile *newDirectory = [GTLDriveFile object];
        newDirectory.identifier = nil;
        newDirectory.title = nil;
        [list insertObject:newDirectory atIndex:1];
    }

    return list;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return [[self directories] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_isInsertingDirectory && indexPath.section == 0 && indexPath.row == 1) {
        static NSString *myIdentifier = @"EditableCellIdentifier";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:myIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:myIdentifier];
        }
        _newDirectoryTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 10, 1004, 25)];
        _newDirectoryTextField.placeholder = @"New Directory Name";
        _newDirectoryTextField.delegate = self;
        [cell.contentView addSubview:_newDirectoryTextField];
        [_newDirectoryTextField becomeFirstResponder];
        return cell;
    } else {
        static NSString *myIdentifier = @"NormalCellIdentifier";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:myIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:myIdentifier];
        }
        NSDictionary *directory = [[self directories] objectAtIndex:indexPath.row];
        cell.textLabel.text = [directory valueForKey:@"title"];
        return cell;
    }
}

- (void)selectDirectory:(GTLDriveFile *)directory
{
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setValue:directory.identifier forKey:@"RemoteDirectoryIdentifier"];
    [prefs setValue:directory.title      forKey:@"RemoteDirectoryTitle"];
    [prefs synchronize];
}

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    GTLDriveFile *directory = [[self directories] objectAtIndex:indexPath.row];
    [self selectDirectory:directory];
    [self dismissModal];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField != _newDirectoryTextField) return YES;

    // Don't allow dismissing if text field is empty since we don't
    // allow creating directories with empty titles
    if ([[textField text] length] < 1) return NO;

    // Dispatch directory creation request to Google Drive
    // - then select directory and dismiss
    GoogleDriveService *gds = [[GoogleDriveService alloc] init];
    NSString *newDirectoryTitle = [_newDirectoryTextField text];
    [gds createDirectoryWithTitle:newDirectoryTitle]
        .then(^(GTLDriveFile *newDirectory) {
            [self selectDirectory:newDirectory];
            [self dismissModal];
        })
        .catch(^(NSError *error) {
            // Log the error
            NSString *message = [NSString stringWithFormat:@"Error creating directory on Google Drive: %@", error.description];
            [TBScopeData CSLog:message inCategory:@"SETTINGS"];

            // Reset the form
            _isInsertingDirectory = NO;
        });

    // Dismiss keyboard
    [_newDirectoryTextField resignFirstResponder];

    return YES;
}

@end
