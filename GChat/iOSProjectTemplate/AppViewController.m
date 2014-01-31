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
#import "GCChatViewController.h"

	#define UI_SIZE_INFO_BUTTON_MARGIN 8

    #define KEY_CELL_ID @"ContactCell"

    typedef enum {
        ContactListSectionsOnline,
        ContactListSectionsOffline,
        ContactListSectionsCount
    } ContactListSections;

@interface AppViewController () <
    UITableViewDataSource
    , UITableViewDelegate
>

    /** Tableview for contact list */
    @property (weak, nonatomic) IBOutlet UITableView *tableView;

    /** Storage for contact list */
    @property (strong, nonatomic) NSMutableArray *contactList;

@end


#pragma mark - Implementation

@implementation AppViewController

/** @brief Initialize data-related properties */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
		self.title = NSLocalizedString(@"APP_VIEW_TITLE", nil);

        _contactList = [NSMutableArray new];
        for (NSInteger i = 0; i < ContactListSectionsCount; ++i) {
            [_contactList addObject:[NSMutableArray new]];
        }

        // Notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(contactPresenceChanged:)
            name:NOTIFICATION_PRESENCE_UPDATE object:nil];
    }
    return self;
}


#pragma mark - View Lifecycle

/** @brief Setup UI elements for viewing. */
- (void)viewDidLoad
{
    [super viewDidLoad];

    // View
	self.view.backgroundColor = [UIColor whiteColor];

    // Setup
	[self setupNavBar];
    [self setupTableView];
}

/** @brief Last-minute setup before view appears. */
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // Connect if have login credentials saved
    if ([[NSUserDefaults standardUserDefaults] objectForKey:CACHE_KEY_LOGIN_USERNAME]) {
        if ([[AppDelegate appDelegate] connect]) {
            debugLog(@"Show Contact List");
        }
    }
    else {    // Ask for login credentials
        [self showLoginView];
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UI Setup

/** @brief Setup Nav bar */
- (void)setupNavBar
{
    // Text Color
    if (deviceOSVersionLessThan(@"7.0")) {
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
    if (deviceOSVersionLessThan(@"7.0")) {
        [[UINavigationBar appearance] setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
        [[UINavigationBar appearance] setBackgroundColor:UIColorFromHex(COLOR_HEX_BACKGROUND_LIGHT)];
    }

    // Login button on left
    NSString *loginTitle = [NSString stringWithFormat:@"%@%@",
        (deviceOSVersionLessThan(@"7.0") ? @"" : @" "),
        NSLocalizedString(@"APP_NAVBAR_LOGIN_BUTTON_TITLE", nil)];
    UIBarButtonItem *loginButton = [[UIBarButtonItem alloc]
        initWithTitle:loginTitle style:UIBarButtonItemStylePlain
        target:self action:@selector(loginButtonTapped:)];
    [self.navigationItem setLeftBarButtonItem:loginButton animated:true];
	
	// Info button on right side
	UIButton *infoButton;
    if (deviceOSVersionLessThan(@"7.0"))
    {
        infoButton = [UIButton buttonWithType:UIButtonTypeInfoDark];
        CGRect frame = infoButton.frame;
        frame.size.width += UI_SIZE_INFO_BUTTON_MARGIN;
        infoButton.frame = frame;
    } else {
        infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    }
	[infoButton addTarget:self action:@selector(infoButtonTapped:)
			forControlEvents:UIControlEventTouchUpInside];
	[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc]
			initWithCustomView:infoButton] animated:true];
}

/** @brief Setup tableview */
- (void)setupTableView
{
    [self.tableView registerClass:[UITableViewCell class]
        forCellReuseIdentifier:KEY_CELL_ID];
}


#pragma mark - Class Functions

/** @brief Show login screen */
- (void)showLoginView
{
    // Set back button on navbar
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:NSLocalizedString(@"LOGIN_NAVBAR_BACK_BUTTON_TITLE", nil)
        style:UIBarButtonItemStylePlain target:nil action:nil];

    // Jump to login page
    [self presentViewController:[[GCLoginViewController alloc]
        initWithNibName:@"GCLoginViewController" bundle:nil]
        animated:true completion:nil];
}

/** @brief Show chat screen */
- (void)showChatView:(NSDictionary *)contact
{
    // Set back button on navbar
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:NSLocalizedString(@"LOGIN_NAVBAR_BACK_BUTTON_TITLE", nil)
        style:UIBarButtonItemStylePlain target:nil action:nil];

    // Jump to login page
    [self.navigationController pushViewController:[[GCChatViewController alloc]
        initWithNibName:@"GCChatViewController" bundle:nil] animated:true];
}

/** @brief Sets contact in offline section */
- (void)setContactOffline:(NSString *)username
{
    // If already in state, return
    if ([self.contactList[ContactListSectionsOffline] containsObject:username]) {
        return;
    }

    // Remove from online if exists
    [self.contactList[ContactListSectionsOnline] removeObject:username];

    // Add to offline
    [self.contactList[ContactListSectionsOffline] addObject:username];

    // Update tableview
    [self.tableView reloadData];
}

/** @brief Sets contact in online section */
- (void)setContactOnline:(NSString *)username
{
    // If already in state, return
    if ([self.contactList[ContactListSectionsOnline] containsObject:username]) {
        return;
    }

    // Remove from offline if exists
    [self.contactList[ContactListSectionsOffline] removeObject:username];

    // Add to online
    [self.contactList[ContactListSectionsOnline] addObject:username];
   
    // Update tableview
    [self.tableView reloadData];
}


#pragma mark - UI Event Handlers

/** @brief Login button pressed */
- (void)loginButtonTapped:(id)sender {
    [self showLoginView];
}

/** @brief Info button pressed */
- (void)infoButtonTapped:(id)sender
{
}

/** @brief When received notification that a contact's presence changed */
- (void)contactPresenceChanged:(NSNotification *)notification
{
    if ([notification.userInfo[@"presence"] isEqualToString:@"unavailable"]) {
        [self setContactOffline:notification.userInfo[@"username"]];
    } else {
        [self setContactOnline:notification.userInfo[@"username"]];
    }
}


#pragma mark - Protocols
#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return ContactListSectionsCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section)
    {
        case ContactListSectionsOnline:
        case ContactListSectionsOffline:
            return [self.contactList[section] count];

        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:KEY_CELL_ID];

    cell.textLabel.text = self.contactList[indexPath.section][indexPath.row];

    return cell;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Animated deselect fade
    [tableView deselectRowAtIndexPath:indexPath animated:true];

    // Show chat view
    [self showChatView:@{
        @"username":self.contactList[indexPath.section][indexPath.row]
    }];
}


@end
