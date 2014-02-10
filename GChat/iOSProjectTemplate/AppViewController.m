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

    @property (assign, nonatomic) BOOL initialRun;

@end


#pragma mark - Implementation

@implementation AppViewController

/** @brief Initialize data-related properties */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
       [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(reachabilityChanged:)
            name:kReachabilityChangedNotification object:nil];
    }
    return self;
}


#pragma mark - View Lifecycle

/** @brief Setup UI elements for viewing. */
- (void)viewDidLoad
{
    [super viewDidLoad];

    // Navbar
    self.navigationController.navigationBarHidden = true;
    
    // Text Color for navbar titles
    if (deviceOSVersionLessThan(iOS7)) {
        [[UINavigationBar appearance] setTitleTextAttributes:@{
            UITextAttributeTextColor: [UIColor darkGrayColor],
            UITextAttributeTextShadowColor: [UIColor clearColor],
            UITextAttributeFont: [UIFont fontWithName:FONT_NAME_LIGHT size:FONT_SIZE_NAVBAR],
        }];
    } else {
        [[UINavigationBar appearance] setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [UIColor darkGrayColor],
            NSFontAttributeName: [UIFont fontWithName:FONT_NAME_THIN size:FONT_SIZE_NAVBAR],
        }];
    }

	// Background Color
	self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
    if (deviceOSVersionLessThan(iOS7)) {
        [[UINavigationBar appearance] setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
        [[UINavigationBar appearance] setBackgroundColor:UIColorFromHex(COLOR_HEX_BACKGROUND_LIGHT)];
    }

    // View
	self.view.backgroundColor = [UIColor whiteColor];
    self.initialRun = true;

    // Contacts View
    self.contactsVC = [[GCContactsViewController alloc] initWithNibName:@"GCContactsViewController" bundle:nil];
    [[[AppDelegate appDelegate] roster] addDelegate:self.contactsVC delegateQueue:dispatch_get_main_queue()];
}

/** @brief Last-minute setup before view appears. */
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    debugLog(@"viewWillAppear");
 
    // Try to connect and show appropriate views
    if ([[AppDelegate appDelegate] connectWithUsername:nil andPassword:nil])
    {
        [self.navigationController pushViewController:self.contactsVC animated:true];
    } else {    // Can't auto connect, need to show login screen
        [self presentViewController:[[GCLoginViewController alloc] initWithNibName:@"GCLoginViewController" bundle:nil] animated:!self.initialRun completion:nil];
    }
    self.initialRun = false;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    debugLog(@"viewDidAppear");

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

- (void)reachabilityChanged:(NSNotification *)notification
{
    debugLog(@"reachabilityChanged");
    debugObject(notification.userInfo);
    debugObject(notification.object);
}


#pragma mark - Protocols


@end
