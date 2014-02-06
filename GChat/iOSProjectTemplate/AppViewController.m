/**
	@file	AppViewController.m
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.


#import "AppViewController.h"

#import "AppDelegate.h"
#import "GCLoginViewController.h"
#import "GCContactsViewController.h"

@interface AppViewController ()

@end


#pragma mark - Implementation

@implementation AppViewController

/** @brief Initialize data-related properties */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}


#pragma mark - View Lifecycle

/** @brief Setup UI elements for viewing. */
- (void)viewDidLoad
{
    [super viewDidLoad];

    // Hide navbar
    self.navigationController.navigationBarHidden = true;

    // View
	self.view.backgroundColor = [UIColor whiteColor];
}

/** @brief Last-minute setup before view appears. */
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    debugLog(@"viewWillAppear");

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    debugLog(@"viewDidAppear");
    
    // Try to connect and show appropriate views
    if ([[AppDelegate appDelegate] connectWithUsername:nil andPassword:nil]) {
        [self.navigationController pushViewController:[[GCContactsViewController alloc] initWithNibName:@"GCContactsViewController" bundle:nil] animated:true];
    } else {    // Can't auto connect, need to show login screen
        [self presentViewController:[[GCLoginViewController alloc] initWithNibName:@"GCLoginViewController" bundle:nil] animated:true completion:nil];
    }
}

/** @brief Dispose of any resources that can be recreated. */
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

/** @brief Return supported orientations */
- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)dealloc
{
}

#pragma mark - UI Setup


#pragma mark - Class Functions


#pragma mark - UI Event Handlers


#pragma mark - Protocols


@end
