//
//  GCContactsViewController.m
//  GChat
//
//  Created by . Carlin on 2/6/14.
//  Copyright (c) 2014 Carlin. All rights reserved.
//

#import "GCContactsViewController.h"

#import "GCChatViewController.h"
#import "CustomPullToRefreshControl.h"

	#define SIZE_INFO_BUTTON_MARGIN 8
    #define SIZE_CROUTON_MARGIN 8

    #define KEY_CELL_ID @"ContactCell"

    #define XMPP_PRESENCE_SHOW_COMPARE_AWAY @"eway"

    #define TIME_SILENT_REFRESH 1
    #define TIME_PULL_REFRESH 2
    #define TIME_CROUTON_SHOW 2     // 2 seconds
    #define TIME_POLL_ROSTER 20

    #define SIZE_PULLREFRESH_PULLOVER -64
    #define SIZE_PULLREFRESH_HEIGHT -54

    typedef enum {
        ContactListSectionsOnline,
        ContactListSectionsBusy,
        ContactListSectionsAway,
        ContactListSectionsOffline,
        ContactListSectionsCount,
    } ContactListSections;

    // http://xmpp.org/rfcs/rfc3921.html
    typedef enum {
        ContactListStatusOrderChat,
        ContactListStatusOrderDoNotDisturb,
        ContactListStatusOrderAway,
        ContactListStatusOrderExtendedAway,
        ContactListStatusOrderCount,
    } ContactListStatusOrder;

    typedef enum {
        ContactListSortTypeByName,
        ContactListSortTypeByStatus,
        ContactListSortTypeCount,
    } ContactListSortType;

    typedef enum {
        AlertViewTypeAddContact = 1000,
        AlertViewTypeContactRequest,
        AlertViewTypeCount,
    } AlertViewType;
    
@interface GCContactsViewController () <
    UITableViewDataSource
    , UITableViewDelegate
    , XMPPRosterDelegate
    , UIAlertViewDelegate
>

    /** Tableview for contact list */
    @property (weak, nonatomic) IBOutlet UITableView *tableView;
    @property (strong, nonatomic) CustomPullToRefreshControl *pullToRefresh;
    @property (assign, nonatomic) BOOL refreshingTableView;

    /** Storage for contact list */
    @property (strong, nonatomic) NSMutableArray *contactList;
    @property (copy, nonatomic) NSComparisonResult(^contactComparisonBlock)(id obj1, id obj2);

    /** Chat screen */
    @property (strong, nonatomic) GCChatViewController *chatVC;

    /** Storage for subscription requests */
    @property (strong, nonatomic) NSMutableDictionary *subscriptionRequests;

    /** Timers for refreshing */
    @property (strong, nonatomic) NSTimer *refreshTimer;
    @property (strong, nonatomic) NSTimer *pollServerTimer;

    /** Clickable title for navbar to change sorting */
    @property (strong, nonatomic) UIButton *titleButton;
    @property (assign, nonatomic) ContactListSortType sortType;

    /** Crouton messages */
    @property (strong, nonatomic) UILabel *croutonLabel;
    @property (assign, nonatomic) BOOL croutonIsShowing;

@end

@implementation GCContactsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
		self.title = NSLocalizedString(@"APP_VIEW_TITLE", nil);

        // Contact list
        _contactList = [NSMutableArray new];
        for (int i = 0; i < ContactListSectionsCount; ++i) {
            [_contactList addObject:[NSMutableArray new]];
        }

        // Default sorting
        _sortType = [[NSUserDefaults standardUserDefaults] integerForKey:CACHE_KEY_CONTACTS_SORT_TYPE];

        // Subscription requests
        _subscriptionRequests = [NSMutableDictionary new];

        // Status order comparison
        _contactComparisonBlock = ^NSComparisonResult(id obj1, id obj2)
        {
            NSDictionary *d1 = (NSDictionary *)obj1;
            NSDictionary *d2 = (NSDictionary *)obj2;
            NSString *s1 = d1[XMPP_PRESENCE_SHOW];
            NSString *s2 = d2[XMPP_PRESENCE_SHOW];

            // Adjust for away, set it to something between dnd and xa
            if ([s1 isEqualToString:XMPP_PRESENCE_SHOW_AWAY]) {
                s1 = XMPP_PRESENCE_SHOW_COMPARE_AWAY;
            }
            if ([s2 isEqualToString:XMPP_PRESENCE_SHOW_AWAY]) {
                s2 = XMPP_PRESENCE_SHOW_COMPARE_AWAY;
            }

            // Compare statuses, if statuses are equal, compare names
            NSComparisonResult statusCompare = [s1 compare:s2];
            return (statusCompare != NSOrderedSame) ? statusCompare
                : [d1[XMPP_PRESENCE_USERNAME] compare:d2[XMPP_PRESENCE_USERNAME]];
        };

        // Notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(contactPresenceChanged:)
            name:NOTIFICATION_PRESENCE_UPDATE object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(connectionStatusChanged:)
            name:NOTIFICATION_CONNECTION_CHANGED object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(messageReceived:)
            name:NOTIFICATION_MESSAGE_RECEIVED object:nil];
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
    [self setupPullToRefresh];
}

/** @brief Last-minute setup before view appears. */
- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

    debugLog(@"viewWillAppear");

    // Clear navbar color
    [self clearNavBarColor];

    // Deselect from tableview if exists
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:true];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    debugLog(@"viewDidAppear");

    // If signed in and connected, clear notifications
    //  If we're not signed in, AppDelegate will handle
    if ([[AppDelegate appDelegate] connectWithUsername:nil andPassword:nil]) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
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
    // Display
    self.navigationController.navigationBarHidden = false;
    self.navigationItem.hidesBackButton = true;

    // Setup loading indicator
    [self setLoadingIndicator];

    // Clickable title for sorting
    self.titleButton = [UIButton new];
    [self.titleButton setTitle:NSLocalizedString(@"APP_VIEW_TITLE", nil)
        forState:UIControlStateNormal];
    [self.titleButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [self.titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
    self.titleButton.titleLabel.font = (deviceOSVersionLessThan(iOS7))
        ? [UIFont fontWithName:FONT_NAME_LIGHT size:FONT_SIZE_NAVBAR]
        : [UIFont fontWithName:FONT_NAME_THIN size:FONT_SIZE_NAVBAR];
    [self.titleButton addTarget:self action:@selector(titleTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.titleView = self.titleButton;

    // Add contact button on right side (and filter?)
    UIButton *button = [UIButton buttonWithType:UIButtonTypeContactAdd];
    if (deviceOSVersionLessThan(iOS7))
    {
        CGRect frame = button.frame;
        frame.size.width += SIZE_INFO_BUTTON_MARGIN;
        button.frame = frame;
    }
   	[button addTarget:self action:@selector(startChatButtonTapped:)
        forControlEvents:UIControlEventTouchUpInside];
	[self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc]
        initWithCustomView:button] animated:true];
}

/** @brief Setup tableview */
- (void)setupTableView
{
    // TableView
    self.tableView.alpha = 0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = UIColorFromHex(COLOR_HEX_WHITE_TRANSPARENT);

    // Footer for crouton messages
    self.croutonLabel = [[UILabel alloc] initWithFrame:CGRectMake(
        0, CGRectGetMaxY(self.view.frame),
        CGRectGetWidth(self.view.frame), 0
    )];
    self.croutonLabel.backgroundColor = UIColorFromHex(COLOR_HEX_WHITE_TRANSLUCENT);
    self.croutonLabel.textColor = [UIColor darkGrayColor];
    self.croutonLabel.font = [UIFont fontWithName:FONT_NAME_MEDIUM size:FONT_SIZE_CROUTON];
    self.croutonLabel.textAlignment = NSTextAlignmentCenter;
    self.croutonLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.croutonLabel.numberOfLines = 0;
    [self.view addSubview:self.croutonLabel];
}

/** @brief Setup pull to refresh */
- (void)setupPullToRefresh
{
    // NOTE: this needs to happen when insets are already set on UITableView
    self.pullToRefresh = [[CustomPullToRefreshControl alloc] initInScrollView:self.tableView];
    self.pullToRefresh.scrollUpToCancel = true;
    [self.pullToRefresh addTarget:self action:@selector(pulledToRefresh:) forControlEvents:UIControlEventValueChanged];
}


#pragma mark - Class Functions

/** @brief Show chat screen */
- (void)showChatView:(XMPPUserMemoryStorageObject *)contact
{
    // Set back button on navbar
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:NSLocalizedString(@"LOGIN_NAVBAR_BACK_BUTTON_TITLE", nil)
        style:UIBarButtonItemStylePlain target:nil action:nil];

    // Lazy create chat screen
    if (!self.chatVC) {
        self.chatVC = [[GCChatViewController alloc]
            initWithContact:contact];
    } else {
        self.chatVC.contact = contact;
    }

    // Jump to login page
    [self.navigationController
        pushViewController:self.chatVC animated:true];
}

/** @brief Select and open up chat view for a specific contact */
- (void)selectContact:(NSString *)username
{
    if (username)
    {
        XMPPUserMemoryStorageObject *user = [[[AppDelegate appDelegate] rosterStorage] userForJID:[XMPPJID jidWithString:username]];
        if (user) {
            [self showChatView:user];
        }
    }
}

/** @brief Set info button into navbar */
- (void)setInfoButton
{
    debugLog(@"setInfoButton");

    // Info button on left side
	UIButton *infoButton;
    if (deviceOSVersionLessThan(iOS7))
    {
        infoButton = [UIButton buttonWithType:UIButtonTypeInfoDark];
        CGRect frame = infoButton.frame;
        frame.size.width += SIZE_INFO_BUTTON_MARGIN;
        infoButton.frame = frame;
    } else {
        infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    }

	[infoButton addTarget:self action:@selector(infoButtonTapped:)
        forControlEvents:UIControlEventTouchUpInside];
	[self.navigationItem setLeftBarButtonItem:[[UIBarButtonItem alloc]
        initWithCustomView:infoButton] animated:true];
}

/** @brief Set loading indicator into navbar */
- (void)setLoadingIndicator
{
    // Show loading indicator where settings button is
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [loadingIndicator startAnimating];
    button.frame = loadingIndicator.frame;
    [button addSubview:loadingIndicator];

    if (deviceOSVersionLessThan(iOS7))
    {
        CGRect frame = button.frame;
        frame.size.width += SIZE_INFO_BUTTON_MARGIN;
        button.frame = frame;
    }

    // Allow early access to hitting the button
    [button addTarget:self action:@selector(infoButtonTapped:)
        forControlEvents:UIControlEventTouchUpInside];
    [self.navigationItem setLeftBarButtonItem:[[UIBarButtonItem alloc]
        initWithCustomView:button] animated:true];
}

/** @brief Schedules a refresh to happen, if set to override previous, then cancel existing timer if exists, otherwise will not override it and return if an existing timer already exists */
- (void)scheduleRefresh:(NSTimeInterval)delay overridePrevious:(BOOL)override
{
    if (self.refreshTimer)
    {
        // If existing timer: override we cancel it, no-override we exit
        if (override) {
            [self.refreshTimer invalidate];
        } else {
            return;
        }
    }

    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:delay
        target:self selector:@selector(refreshTableView:)
        userInfo:nil repeats:false];
}

/** @brief Manually initiate pull to refresh */
- (void)manualPullToRefresh
{
    // Animate pull-down
    CGFloat originalTopInset = self.tableView.contentInset.top;
    [self.pullToRefresh beginRefreshing];
    [UIView animateWithDuration:ANIMATION_DURATION_FAST delay:0
        options:UIViewAnimationOptionCurveEaseInOut
            | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
            [self.tableView setContentOffset:CGPointMake(0, SIZE_PULLREFRESH_PULLOVER - originalTopInset)];
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:ANIMATION_DURATION_FAST delay: 0
                options:UIViewAnimationOptionCurveEaseOut
                    | UIViewAnimationOptionBeginFromCurrentState
                animations:^{
                    [self.tableView setContentOffset:CGPointMake(0, SIZE_PULLREFRESH_HEIGHT - originalTopInset)];
                } completion:nil];
        }];
    [self scheduleRefresh:TIME_PULL_REFRESH overridePrevious:true];
}

/** @brief Silent refresh, only shows activity indicator in status bar */
- (void)silentRefresh:(id)sender
{
    debugLog(@"silentRefresh from %@", sender);

    // Show loading indicator
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:true];

    // Refresh
    [self scheduleRefresh:TIME_SILENT_REFRESH overridePrevious:false];
}

/** @brief Clears contact list and replaces contents with blank arrays */
- (void)clearContactList
{
    for (int i = 0; i < ContactListSectionsCount; ++i) {
        self.contactList[i] = [NSMutableArray new];
    }
}

/** @brief Refreshes tableview and roster data */
- (void)refreshTableView:(id)sender
{
    // Don't refresh if already refreshing
    if (self.refreshingTableView) {
        return;
    }

    self.refreshingTableView = true;

    // Do this asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{

        // Get new snapshot of roster
        XMPPRosterMemoryStorage *rosterStorage = [[AppDelegate appDelegate] rosterStorage];

        // Clean up contact list
        [self clearContactList];

        // If sorted by name
        if (self.sortType == ContactListSortTypeByName)
        {
            debugLog(@"sortedByName");

            if (rosterStorage && [rosterStorage sortedAvailableUsersByName]) {
                [self.contactList[ContactListSectionsOnline]
                    addObjectsFromArray:[rosterStorage sortedAvailableUsersByName]];
            }
            if (rosterStorage && [rosterStorage sortedUnavailableUsersByName]) {
                [self.contactList[ContactListSectionsOffline]
                    addObjectsFromArray:[rosterStorage sortedUnavailableUsersByName]];
            }
        }
        else if (self.sortType == ContactListSortTypeByStatus)
        {
            debugLog(@"sortedByStatus");

            // Create easy hashmap for efficient referencing
            NSDictionary *sections = @{
                XMPP_PRESENCE_SHOW_AWAY: self.contactList[ContactListSectionsAway],
                XMPP_PRESENCE_SHOW_AWAY_EXTENDED: self.contactList[ContactListSectionsAway],
                XMPP_PRESENCE_SHOW_BUSY: self.contactList[ContactListSectionsBusy],
                XMPP_PRESENCE_TYPE_ONLINE: self.contactList[ContactListSectionsOnline],
                XMPP_PRESENCE_TYPE_OFFLINE: self.contactList[ContactListSectionsOffline],
            };

            // Iterate through sorted users by availability and insert
            NSArray *sortedUsers = [rosterStorage sortedUsersByAvailabilityName];
            NSString *show;
            for (XMPPUserMemoryStorageObject *user in sortedUsers)
            {
                // If no primaryResource, is offline
                show = ([user primaryResource]
                    ? [[[user primaryResource] presence] show]
                    : XMPP_PRESENCE_TYPE_OFFLINE);
                show = (show ? show : XMPP_PRESENCE_TYPE_ONLINE);

                // Add to appropriate section
                [sections[show] addObject:user];
            }
        }

        // Do this on main ui thread
        dispatch_sync(dispatch_get_main_queue(), ^
        {
            // Clear flag
            self.refreshingTableView = false;

            // Refresh tableview
            [self.tableView reloadData];
//            [self.tableView reloadSections:[NSIndexSet
//                    indexSetWithIndexesInRange:NSMakeRange(0, ContactListSectionsCount)]
//                withRowAnimation:UITableViewRowAnimationAutomatic];

            // Show tableview if not already shown
            [UIView animateWithDuration:ANIMATION_DURATION_FAST
                delay:ANIMATION_DURATION_MED
                options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                animations:^{
                    self.tableView.alpha = 1;
                } completion:nil];

            // Stop refreshing if pull to refresh is running
            [self.pullToRefresh endRefreshing];

            // Stop activity indicator if it was showing
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:false];

            // Clear timer
            self.refreshTimer = nil;

            // Make sure to show info button at this point
            [self setInfoButton];
        });
    });
}

/** @brief Show crouton with message */
- (void)croutonWithMessage:(NSString *)message
{
    debugLog(@"crouton: %@", message);
}
 
/** @brief Start polling timer */
- (void)startPollingTimer
{
    [self cancelPollingTimer];
    self.pollServerTimer = [NSTimer scheduledTimerWithTimeInterval:TIME_POLL_ROSTER target:self selector:@selector(silentRefresh:) userInfo:nil repeats:true];
}

/** @brief Cancel polling timer */
- (void)cancelPollingTimer
{
    if (self.pollServerTimer) {
        [self.pollServerTimer invalidate];
    }
}

/** @brief Shows popup entry for adding a new contact */
- (void)showAddContactEntry
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"APP_CONTACTS_ADD_TITLE", nil)
        message:NSLocalizedString(@"APP_CONTACTS_ADD_MESSAGE", nil)
        delegate:self
        cancelButtonTitle:NSLocalizedString(@"POPUP_CANCEL_BUTTON_TITLE", nil)
        otherButtonTitles:NSLocalizedString(@"APP_CONTACTS_ADD_OK", nil), nil];
    alert.tag = AlertViewTypeAddContact;
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;

    // Setup field to be email field and show
    [[alert textFieldAtIndex:0] setKeyboardAppearance:UIKeyboardAppearanceAlert];
    [[alert textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeEmailAddress];
    [alert show];
}

/** @brief Show subscribe request */
- (void)showSubscribeRequest:(XMPPJID *)fromUser
{
    // Someone asked to add you to his buddy list
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"APP_CONTACTS_SUBSCRIBE_REQUEST_TITLE", nil)
        message:[NSString stringWithFormat:@"%@@%@ %@",
            [fromUser user], [fromUser domain],
            NSLocalizedString(@"APP_CONTACTS_SUBSCRIBE_REQUEST_MESSAGE", nil)]
        delegate:self
        cancelButtonTitle:NSLocalizedString(@"APP_CONTACTS_SUBSCRIBE_REQUEST_CANCEL", nil)
        otherButtonTitles:NSLocalizedString(@"APP_CONTACTS_SUBSCRIBE_REQUEST_OK", nil), nil];
    alert.tag = AlertViewTypeContactRequest;

    // Hash and store request
    [self.subscriptionRequests setObject:fromUser forKey:@([alert hash])];

    // Show popup
    [alert show];
}

/** @brief Clears navbar color */
- (void)clearNavBarColor
{
    if (deviceOSVersionLessThan(iOS7)) {
        self.navigationController.navigationBar.tintColor
            = UIColorFromHex(COLOR_HEX_BACKGROUND_LIGHT);
    } else {
        self.navigationController.navigationBar.barTintColor = nil;
    }
}


#pragma mark - UI Event Handlers

/** @brief Logout button pressed */
- (void)logoutButtonTapped:(id)sender
{
    debugLog(@"Logging out");

    // Disconnect xmpp service
    [[AppDelegate appDelegate] disconnect];

    // Stop timer for polling
    [self cancelPollingTimer];

    // Clear credentials
    [AppDelegate clearCredentials];

    // Clear data
    __block GCContactsViewController *this = self;
    [UIView animateWithDuration:ANIMATION_DURATION_FAST delay:0
        options:UIViewAnimationOptionCurveEaseInOut
        animations:^{
            if (this) {
                this.tableView.alpha = 0;
            }
        } completion:^(BOOL finished) {
            if (this) {
                [this.contactList removeAllObjects];
                [this.tableView reloadData];
                [this setLoadingIndicator];
                [this.navigationController popViewControllerAnimated:true];
            }
        }];
}

/** @brief Info button pressed */
- (void)infoButtonTapped:(UIButton *)sender
{
    [self logoutButtonTapped:sender];
}

/** @brief Start chat button pressed */
- (void)startChatButtonTapped:(UIButton *)sender
{
    
}

/** @brief When received notification that a contact's presence changed */
- (void)contactPresenceChanged:(NSNotification *)notification
{
    debugLog(@"contactPresenceChanged: %@", notification.userInfo);

    // TODO: Update tableview
    // Find row for the user with modified presence
    // Find new location for row
    // Make updates and animate
}

/** @brief When connection status to xmpp service changes */
- (void)connectionStatusChanged:(NSNotification *)notification
{
    NSString *status = notification.userInfo[XMPP_STATUS];

    // If connected
    if ([status isEqualToString:XMPP_CONNECTION_OK])
    {
        // Set timer to continuously poll server
        [self startPollingTimer];
    }
    else if ([status isEqualToString:XMPP_CONNECTION_CONNECTING])
    {
    }
    else if ([status isEqualToString:XMPP_CONNECTION_ERROR_TIMEOUT])
    {
    }
    else if ([status isEqualToString:XMPP_CONNECTION_AUTH])
    {
    }
    else if ([status isEqualToString:XMPP_CONNECTION_ERROR])
    {
    }
}

/** @brief When tableview is pulled to refresh */
- (void)pulledToRefresh:(id)sender
{
    debugLog(@"pulledToRefresh");

    // Manually fetch
    [[[AppDelegate appDelegate] roster] fetchRoster];

    // Refresh on delay
    [self scheduleRefresh:TIME_PULL_REFRESH overridePrevious:true];
}

/** @brief When title button is tapped to change sorting */
- (void)titleTapped:(UIButton *)sender
{
    debugLog(@"titleTapped");

    // Rotate through sort types
    self.sortType = (self.sortType + 1) % ContactListSortTypeCount;

    // Store into user settings
    [[NSUserDefaults standardUserDefaults] setInteger:self.sortType forKey:CACHE_KEY_CONTACTS_SORT_TYPE];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Refresh
    [self manualPullToRefresh];
}

/** @brief When we get a message */
- (void)messageReceived:(NSNotification *)notification
{
    debugLog(@"%@", self.presentedViewController);

    // Only notify if we are the active screen
    if ([[self.navigationController.viewControllers lastObject] isEqual:self])
    {
        debugLog(@"ContactList messageReceived: %@", notification);
        NSDictionary *message = notification.userInfo;

        // Create local notification
        UILocalNotification *pushNotification = [UILocalNotification new];
        pushNotification.soundName = UILocalNotificationDefaultSoundName;
        pushNotification.alertBody = [NSString stringWithFormat:@"%@ : %@",
            message[XMPP_MESSAGE_USERNAME], message[XMPP_MESSAGE_TEXT]];
        pushNotification.alertAction = NSLocalizedString(@"PN_ACTION_TITLE", nil);
        pushNotification.applicationIconBadgeNumber = 1;
        pushNotification.userInfo = message;

        // Show notification immediately
        [[UIApplication sharedApplication] presentLocalNotificationNow:pushNotification];
    }
}


#pragma mark - Protocols
#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.contactList.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section)
    {
        case ContactListSectionsOnline:
        case ContactListSectionsBusy:
        case ContactListSectionsAway:
        case ContactListSectionsOffline:
            return [self.contactList[section] count];

        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:KEY_CELL_ID];

    // Create cell if DNE
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:KEY_CELL_ID];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.selectedBackgroundView = [[UIView alloc] initWithFrame:cell.bounds];
    }

    XMPPUserMemoryStorageObject *user;
    switch (indexPath.section)
    {
        case ContactListSectionsOnline:
        case ContactListSectionsBusy:
        case ContactListSectionsAway:
        case ContactListSectionsOffline:
            user = self.contactList[indexPath.section][indexPath.row];
            break;

        default: break;
    }

    // Large text field
    cell.textLabel.text = [user displayName];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.font = [UIFont fontWithName:FONT_NAME_LIGHT size:FONT_SIZE_CONTACT_NAME];
    cell.textLabel.textColor = UIColorFromHex(COLOR_HEX_BACKGROUND_DARK);

    // Detailed text field
    cell.detailTextLabel.text = [[[user primaryResource] presence] status];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.textColor = UIColorFromHex(COLOR_HEX_BLACK_TRANSPARENT);
    cell.detailTextLabel.font = [UIFont fontWithName:FONT_NAME_MEDIUM size:FONT_SIZE_CONTACT_STATUS];

    // Show indicator
    NSString *show = [[[user primaryResource] presence] show];
    if ([show isEqualToString:XMPP_PRESENCE_SHOW_AWAY]
        || [show isEqualToString:XMPP_PRESENCE_SHOW_AWAY_EXTENDED]) {
        cell.contentView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_AWAY);
        cell.selectedBackgroundView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_AWAY_SELECTED);
    } else if ([show isEqualToString:XMPP_PRESENCE_SHOW_BUSY]) {
        cell.contentView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_BUSY);
        cell.selectedBackgroundView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_BUSY_SELECTED);
    }
    else    // Determine color based on presence type
    {
        if (![user primaryResource] || [[[[user primaryResource] presence] type] isEqualToString:XMPP_PRESENCE_TYPE_OFFLINE]) {
            cell.contentView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_OFFLINE);
            cell.selectedBackgroundView.backgroundColor = UIColorFromHex(COLOR_HEX_GREY_TRANSPARENT);
        } else {
            cell.contentView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_ONLINE);
            cell.selectedBackgroundView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_ONLINE_SELECTED);
        }
    }

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    // Don't show header if no entries
    if (![self.contactList[section] count]) {
        return nil;
    }

    switch (section)
    {
        case ContactListSectionsOnline:
            return NSLocalizedString(@"APP_CONTACTS_ONLINE_SECTION_TITLE", nil);

        case ContactListSectionsAway:
            return NSLocalizedString(@"APP_CONTACTS_AWAY_SECTION_TITLE", nil);

        case ContactListSectionsBusy:
            return NSLocalizedString(@"APP_CONTACTS_BUSY_SECTION_TITLE", nil);

        case ContactListSectionsOffline:
            return NSLocalizedString(@"APP_CONTACTS_OFFLINE_SECTION_TITLE", nil);

        default: return nil;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // If has status, add extra space
    XMPPUserMemoryStorageObject *user = self.contactList[indexPath.section][indexPath.row];
    NSString *status = [[[user primaryResource] presence] status];
    if (status && status.length) {
        return SIZE_MIN_TOUCH * 1.5;
    }

    return SIZE_MIN_TOUCH;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    XMPPUserMemoryStorageObject *user;
    switch (indexPath.section)
    {
        case ContactListSectionsOnline:
        case ContactListSectionsBusy:
        case ContactListSectionsAway:
        case ContactListSectionsOffline:
            user = self.contactList[indexPath.section][indexPath.row];
            break;

        default: break;
    }

    // Show chat view
    [self showChatView:user];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Set this so when animating selection, will not fade to white
    cell.backgroundColor = cell.contentView.backgroundColor;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        debugLog(@"delete row at %@", indexPath);

        // Get list to delete user from
        NSMutableArray *list = self.contactList[indexPath.section];
        if (list)
        {
            XMPPUserMemoryStorageObject *user = list[indexPath.row];
            XMPPRoster *roster = [[AppDelegate appDelegate] roster];
            if (user)
            {
                [list removeObject:user];
                [roster unsubscribePresenceFromUser:[user jid]];
                [roster revokePresencePermissionFromUser:[user jid]];
                [roster removeUser:[user jid]];
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
            }
        }
    }
}


#pragma mark - XMPPRosterDelegate

- (void)xmppRosterDidBeginPopulating:(XMPPRoster *)sender
{
    debugLog(@"roster began populating");
}

- (void)xmppRosterDidEndPopulating:(XMPPRoster *)sender
{
    debugLog(@"roster ended populating");
    debugLog(@"roster: %@", [[[AppDelegate appDelegate] rosterStorage] sortedUsersByName]);

    // Instant refresh
    [self scheduleRefresh:TIME_SILENT_REFRESH / 2 overridePrevious:true];
}

- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence
{
    debugLog(@"roster received subscribe request: %@", presence);

//    [self showSubscribeRequest:[presence from]];
}

- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterPush:(XMPPIQ *)iq
{
    debugLog(@"roster received push: %@", iq);
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    XMPPRoster *roster = [[AppDelegate appDelegate] roster];
    NSNumber *key = @([alertView hash]);

    switch (alertView.tag)
    {
        case AlertViewTypeContactRequest:
        {
            if (buttonIndex) // User clicked Accept
            {
                [roster acceptPresenceSubscriptionRequestFrom:[self.subscriptionRequests objectForKey:key]
                    andAddToRoster:true];
            }
            else    // Reject request
            {
                [roster rejectPresenceSubscriptionRequestFrom:[self.subscriptionRequests objectForKey:key]];
            }

            // Clean up request from temp store
            [self.subscriptionRequests removeObjectForKey:key];
        } break;

        case AlertViewTypeAddContact:
        {
            if (buttonIndex) // User clicked Add
            {
                // Send request
                NSString *contactEmail = [[alertView textFieldAtIndex:0] text];

                // Validate email
                if (![[NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", REGEX_EMAIL_VERIFICATION] evaluateWithObject:contactEmail]) {
                    [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"POPUP_ERROR_TITLE", nil) message:NSLocalizedString(@"ERROR_INVALID_EMAIL", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"POPUP_CONFIRM_BUTTON_TITLE", nil) otherButtonTitles:nil] show];
                    return;
                }

                // Add to roster
                XMPPJID *toJID = [XMPPJID jidWithString:contactEmail];
                [roster subscribePresenceToUser:toJID];
                [roster addUser:toJID withNickname:nil];

                // Notify user that request has been sent
                [self croutonWithMessage:NSLocalizedString(@"APP_CONTACTS_ADD_CONFIRM_MESSAGE", nil)];
            }
        } break;

        default: break;
    }
}

@end
