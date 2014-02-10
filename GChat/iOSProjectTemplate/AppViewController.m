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

    #define TIME_REACHABILITY_WARNING 6

@interface AppViewController ()

    @property (assign, nonatomic) BOOL initialRun;

    @property (strong, nonatomic) NSTimer *reachabilityTimer;

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
    UIFont *navbarFont = [UIFont fontWithName:FONT_NAME_LIGHT size:FONT_SIZE_NAVBAR];
    UIColor *navbarColor = UIColorFromHex(COLOR_HEX_BACKGROUND_DARK);
    if (deviceOSVersionLessThan(iOS7)) {
        [[UINavigationBar appearance] setTitleTextAttributes:@{
            UITextAttributeTextColor: navbarColor,
            UITextAttributeTextShadowColor: [UIColor clearColor],
            UITextAttributeFont: navbarFont,
        }];
    } else {
        [[UINavigationBar appearance] setTitleTextAttributes:@{
            NSForegroundColorAttributeName: navbarColor,
            NSFontAttributeName: navbarFont,
        }];
    }

	// Background Color
	self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
    if (deviceOSVersionLessThan(iOS7)) {
        self.navigationController.navigationBar.tintColor
            = UIColorFromHex(COLOR_HEX_BACKGROUND_LIGHT);
    }

    // View
	self.view.backgroundColor = [UIColor whiteColor];
    self.initialRun = true;
}

/** @brief Last-minute setup before view appears. */
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    debugLog(@"viewWillAppear");
 
    // Try to connect and show appropriate views
    if ([[AppDelegate appDelegate] connectWithUsername:nil andPassword:nil])
    {
        // Contacts View - create here and add delegate when xmpp is setup
        if (!self.contactsVC) {
            self.contactsVC = [[GCContactsViewController alloc]
                initWithNibName:@"GCContactsViewController" bundle:nil];
            [[[AppDelegate appDelegate] roster] addDelegate:self.contactsVC
                delegateQueue:dispatch_get_main_queue()];
        }
        [self.navigationController pushViewController:self.contactsVC animated:true];
    }
    else {    // Can't auto connect, need to show login screen
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

- (void)cancelReachabilityTimer
{
    if (self.reachabilityTimer) {
        [self.reachabilityTimer invalidate];
    }
    self.reachabilityTimer = nil;
}

- (void)startReachabilityTimer
{
    self.reachabilityTimer = [NSTimer scheduledTimerWithTimeInterval:TIME_REACHABILITY_WARNING
        target:self selector:@selector(showNoConnectionWarning:)
        userInfo:nil repeats:false];
}

- (void)showNoConnectionWarning:(NSTimer *)sender
{
    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"POPUP_WARNING_TITLE", nil)
        message:NSLocalizedString(@"ERROR_REACHABILITY", nil)
        delegate:nil cancelButtonTitle:NSLocalizedString(@"POPUP_CONFIRM_BUTTON_TITLE", nil)
        otherButtonTitles:nil] show];
}


#pragma mark - UI Event Handlers

- (void)reachabilityChanged:(NSNotification *)notification
{
    Reachability *reachability = (Reachability *)notification.object;
    debugLog(@"reachabilityChanged: %@", [reachability currentReachabilityString]);

    // If we're ever out of connection, fire off timer before showing message about no connection
    [self cancelReachabilityTimer];
    if (![reachability isReachable]) {
        [self startReachabilityTimer];
    }
}


#pragma mark - Protocols


@end
