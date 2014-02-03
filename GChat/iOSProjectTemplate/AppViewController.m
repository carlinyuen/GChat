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
#import "CustomPullToRefreshControl.h"

	#define UI_SIZE_INFO_BUTTON_MARGIN 8

    #define KEY_CELL_ID @"ContactCell"

    #define XMPP_PRESENCE_SHOW_COMPARE_AWAY @"eway"

    #define TIME_REFRESH 2  // 2 seconds

    #define SIZE_PULLREFRESH_PULLOVER -64
    #define SIZE_PULLREFRESH_HEIGHT -54

    typedef enum {
        ContactListSectionsOnline,
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

@interface AppViewController () <
    UITableViewDataSource
    , UITableViewDelegate
    , XMPPRosterDelegate
    , UIAlertViewDelegate
>

    /** Tableview for contact list */
    @property (weak, nonatomic) IBOutlet UITableView *tableView;
    @property (strong, nonatomic) CustomPullToRefreshControl *pullToRefresh;

    /** Storage for contact list */
    @property (strong, nonatomic) NSMutableArray *contactList;
    @property (copy, nonatomic) NSComparisonResult(^contactComparisonBlock)(id obj1, id obj2);

    /** Storage for subscription requests */
    @property (strong, nonatomic) NSMutableDictionary *subscriptionRequests;

    /** Clickable title for navbar to change sorting */
    @property (strong, nonatomic) UIButton *titleButton;
    @property (assign, nonatomic) ContactListSortType sortType;

@end


#pragma mark - Implementation

@implementation AppViewController

/** @brief Initialize data-related properties */
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

    debugLog(@"viewDidAppear");

    // Setup pull to refresh when UITableView insets are set
    if (!self.pullToRefresh) {
        [self setupPullToRefresh];
    }

    // Deselect from tableview if exists
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:true];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    debugLog(@"viewDidAppear");

    // Try to connect, if fails, show login
    if (![[AppDelegate appDelegate] connectWithUsername:nil andPassword:nil]) {
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
	// Background Color
	self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
    if (deviceOSVersionLessThan(iOS7)) {
        [[UINavigationBar appearance] setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
        [[UINavigationBar appearance] setBackgroundColor:UIColorFromHex(COLOR_HEX_BACKGROUND_LIGHT)];
    }

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

	// Info button on right side
	UIButton *infoButton;
    if (deviceOSVersionLessThan(iOS7))
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
    // TableView
    self.tableView.alpha = 0;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = UIColorFromHex(COLOR_HEX_WHITE_TRANSPARENT);
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

/** @brief Show login screen */
- (void)showLoginView
{
    debugLog(@"showLoginView");

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
- (void)showChatView:(XMPPUserMemoryStorageObject *)contact
{
    // Set back button on navbar
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:NSLocalizedString(@"LOGIN_NAVBAR_BACK_BUTTON_TITLE", nil)
        style:UIBarButtonItemStylePlain target:nil action:nil];

    // Jump to login page
    [self.navigationController
        pushViewController:[[GCChatViewController alloc]
            initWithContact:contact] animated:true];
}

/** @brief Refreshes the login button text */
- (void)refreshLoginButton
{
    // Depending on state of logged in status, change text on login button
    NSString *buttonTitle
        = ([[AppDelegate appDelegate] isConnected]
            ? NSLocalizedString(@"APP_NAVBAR_LOGOUT_BUTTON_TITLE", nil)
            : NSLocalizedString(@"APP_NAVBAR_LOGIN_BUTTON_TITLE", nil));

    // Only refresh if state is changed
    if ([[self.navigationItem.leftBarButtonItem title] isEqualToString:buttonTitle]) {
        return;
    }
        
    // Login button on left
    NSString *loginTitle = [NSString stringWithFormat:@"%@%@",
        (deviceOSVersionLessThan(iOS7) ? @"" : @" "), buttonTitle];
    UIBarButtonItem *button = [[UIBarButtonItem alloc]
        initWithTitle:loginTitle style:UIBarButtonItemStylePlain
        target:self action:([[AppDelegate appDelegate] isConnected]
            ? @selector(logoutButtonTapped:) : @selector(loginButtonTapped:))];
    [self.navigationItem setLeftBarButtonItem:button animated:true];
}

/** @brief Sets contact in offline section */
- (void)setContactOffline:(NSDictionary *)contact
{
    // Remove from online if exists
    NSArray *contacts = self.contactList[ContactListSectionsOnline];
    NSInteger index = [contacts indexOfObject:contact inSortedRange:NSMakeRange(0, contacts.count) options:NSBinarySearchingFirstEqual usingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSDictionary *d1 = (NSDictionary *)obj1;
            NSDictionary *d2 = (NSDictionary *)obj2;
            return [d1[@"name"] compare:d2[@"name"]];
        }];
    if (index != NSNotFound) {
        [self.contactList[ContactListSectionsOnline] removeObjectAtIndex:index];
    }

    // Update tableview
    [self.tableView reloadData];
}

/** @brief Sets contact in online section */
- (void)setContactOnline:(NSDictionary *)contact
{
    // Add to online
    NSArray *onlineContacts = self.contactList[ContactListSectionsOnline];
    NSInteger index = [onlineContacts indexOfObject:contact inSortedRange:NSMakeRange(0, onlineContacts.count) options:NSBinarySearchingInsertionIndex usingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSDictionary *d1 = (NSDictionary *)obj1;
            NSDictionary *d2 = (NSDictionary *)obj2;
            return [d1[@"name"] compare:d2[@"name"]];
        }];
    [self.contactList[ContactListSectionsOnline] insertObject:contact
        atIndex:index];

    // Update tableview
    [self.tableView reloadData];
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
    [NSTimer scheduledTimerWithTimeInterval:TIME_REFRESH target:self selector:@selector(refreshTableView:) userInfo:nil repeats:false];
}

/** @brief Refreshes tableview and roster data */
- (void)refreshTableView:(id)sender
{
    // Get new snapshot of roster
    XMPPRosterMemoryStorage *rosterStorage = [[AppDelegate appDelegate] rosterStorage];
    if (rosterStorage && [rosterStorage sortedAvailableUsersByName]) {
        self.contactList[ContactListSectionsOnline] = [rosterStorage sortedAvailableUsersByName];
    }
    if (rosterStorage && [rosterStorage sortedUnavailableUsersByName]) {
        self.contactList[ContactListSectionsOffline] = [[[AppDelegate appDelegate] rosterStorage] sortedUnavailableUsersByName];
    }

    // Refresh tableview
    [self.tableView reloadData];

    // Stop refreshing if pull to refresh is running
    [self.pullToRefresh endRefreshing];
}


#pragma mark - UI Event Handlers

/** @brief Login button pressed */
- (void)loginButtonTapped:(id)sender
{
    // Show login view
    [self showLoginView];
}

/** @brief Logout button pressed */
- (void)logoutButtonTapped:(id)sender
{
    debugLog(@"Logging out");

    // Disconnect xmpp service
    [[AppDelegate appDelegate] disconnect];

    // Clear credentials
    [AppDelegate clearCredentials];

    // Hide tableview
    [UIView animateWithDuration:ANIMATION_DURATION_FAST delay:0
        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
        animations:^{
            self.tableView.alpha = 0;
        } completion:nil];

    // Show login view
    [self showLoginView];
}

/** @brief Info button pressed */
- (void)infoButtonTapped:(id)sender
{
}

/** @brief When received notification that a contact's presence changed */
- (void)contactPresenceChanged:(NSNotification *)notification
{
    debugLog(@"contactPresenceChanged: %@", notification.userInfo);

    return; // Don't change for now

    NSDictionary *data = notification.userInfo;
    if ([data[@"presence"] isEqualToString:@"unavailable"]) {
        [self setContactOffline:data];
    } else {
        [self setContactOnline:data];
    }
}

/** @brief When connection status to xmpp service changes */
- (void)connectionStatusChanged:(NSNotification *)notification
{
    NSString *status = notification.userInfo[XMPP_STATUS];

    // If connected
    if ([status isEqualToString:XMPP_CONNECTION_OK])
    {
        // Refresh login button
        [self refreshLoginButton];

        // Show tableview
        [UIView animateWithDuration:ANIMATION_DURATION_FAST delay:0
            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
            animations:^{
                self.tableView.alpha = 1;
            } completion:nil];

        // Manual pull to refresh
        [self manualPullToRefresh];
    }
    else if ([status isEqualToString:XMPP_CONNECTION_CONNECTING])
    {
        // Show loading indicator where login button is
        UIActivityIndicatorView *loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [loadingIndicator startAnimating];

        if (deviceOSVersionLessThan(iOS7))
        {
            CGRect frame = loadingIndicator.frame;
            frame.size.width += UI_SIZE_INFO_BUTTON_MARGIN;
            loadingIndicator.frame = frame;
        }

        UIBarButtonItem *barButton = [[UIBarButtonItem alloc]
            initWithCustomView:loadingIndicator];
        [self.navigationItem setLeftBarButtonItem:barButton animated:true];
    }
}

/** @brief When tableview is pulled to refresh */
- (void)pulledToRefresh:(id)sender
{
    debugLog(@"pulledToRefresh");

    // Manually fetch
    [[[AppDelegate appDelegate] roster] fetchRoster];

    // Refresh on delay
    [NSTimer scheduledTimerWithTimeInterval:TIME_REFRESH target:self selector:@selector(refreshTableView:) userInfo:Nil repeats:false];
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
        case ContactListSectionsOffline:
            user = self.contactList[indexPath.section][indexPath.row];
            break;

        default: break;
    }

    // Large text field
    cell.textLabel.text = [user displayName];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.font = [UIFont fontWithName:FONT_NAME_LIGHT size:FONT_SIZE_CONTACT_NAME];

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
    switch (section)
    {
        case ContactListSectionsOnline:
            return NSLocalizedString(@"APP_CONTACTS_ONLINE_SECTION_TITLE", nil);

        case ContactListSectionsOffline:
            return NSLocalizedString(@"APP_CONTACTS_OFFLINE_SECTION_TITLE", nil);

        default: return @"";
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


#pragma mark - XMPPRosterDelegate

- (void)xmppRosterDidBeginPopulating:(XMPPRoster *)sender
{
    debugLog(@"roster began populating");
}

- (void)xmppRosterDidEndPopulating:(XMPPRoster *)sender
{
    debugLog(@"roster ended populating");
    debugLog(@"roster: %@", [[[AppDelegate appDelegate] rosterStorage] sortedUsersByName]);
}

- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence
{
    // Someone asked to add you to his buddy list
    XMPPJID *fromUser = [presence from];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"APP_CONTACTS_SUBSCRIBE_REQUEST_TITLE", nil)
        message:[NSString stringWithFormat:@"%@@%@ %@",
            [fromUser user], [fromUser domain],
            NSLocalizedString(@"APP_CONTACTS_SUBSCRIBE_REQUEST_MESSAGE", nil)]
        delegate:self
        cancelButtonTitle:NSLocalizedString(@"APP_CONTACTS_SUBSCRIBE_REQUEST_CANCEL", nil)
        otherButtonTitles:NSLocalizedString(@"APP_CONTACTS_SUBSCRIBE_REQUEST_OK", nil), nil];

    // Hash and store request
    alert.tag = [alert hash];
    [self.subscriptionRequests setObject:fromUser forKey:@(alert.tag)];

    // Show popup
    [alert show];
}

- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterPush:(XMPPIQ *)iq
{
    debugLog(@"roster received push: %@", iq);
}

- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterItem:(NSXMLElement *)item
{
    debugLog(@"roster received item: %@", item);
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // User clicked Accept
    if (buttonIndex)
    {
        [[[AppDelegate appDelegate] roster]
            acceptPresenceSubscriptionRequestFrom:[self.subscriptionRequests objectForKey:@(alertView.tag)]
            andAddToRoster:true];
    }
    else    // Reject request
    {
        [[[AppDelegate appDelegate] roster]
            rejectPresenceSubscriptionRequestFrom:[self.subscriptionRequests objectForKey:@(alertView.tag)]];
    }
}


@end
