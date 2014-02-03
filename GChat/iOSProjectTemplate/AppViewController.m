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

@interface AppViewController () <
    UITableViewDataSource
    , UITableViewDelegate
    , XMPPRosterDelegate
>

    /** Tableview for contact list */
    @property (weak, nonatomic) IBOutlet UITableView *tableView;
    @property (strong, nonatomic) CustomPullToRefreshControl *pullToRefresh;

    /** Storage for contact list */
    @property (strong, nonatomic) NSMutableArray *contactList;
    @property (copy, nonatomic) NSComparisonResult(^contactComparisonBlock)(id obj1, id obj2);

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

    // Refresh roster
    [self refreshTableView];
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
    // Text Color
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
    // Pull to refresh
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

/** @brief Refreshes tableview and roster data */
- (void)refreshTableView
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
    // Refresh login button
    [self refreshLoginButton];
}

/** @brief When tableview is pulled to refresh */
- (void)pulledToRefresh:(id)sender
{
    debugLog(@"pulledToRefresh");

    // Manually fetch
    [[[AppDelegate appDelegate] roster] fetchRoster];
    [self refreshTableView];
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
//            return [[[[AppDelegate appDelegate] rosterStorage] sortedAvailableUsersByName] count];

        case ContactListSectionsOffline:
//            return [[[[AppDelegate appDelegate] rosterStorage] sortedUnavailableUsersByName] count];
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
    cell.textLabel.text = [user displayName];
    cell.detailTextLabel.text = [[[user primaryResource] presence] status];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];

    // Show indicator
    NSString *show = [[[user primaryResource] presence] show];
    if ([show isEqualToString:XMPP_PRESENCE_SHOW_AWAY]) {
        cell.contentView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_AWAY);
    } else if ([show isEqualToString:XMPP_PRESENCE_SHOW_BUSY]) {
        cell.contentView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_BUSY);
    } else if ([show isEqualToString:XMPP_PRESENCE_SHOW_AWAY_EXTENDED]) {
        cell.contentView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_AWAY);
    }
    else    // Determine color based on presence type
    {
        NSString *type = [[[user primaryResource] presence] type];
        if ([type isEqualToString:XMPP_PRESENCE_TYPE_OFFLINE]) {
            cell.contentView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_OFFLINE);
        } else {
            cell.contentView.backgroundColor = UIColorFromHex(COLOR_HEX_SHOW_ONLINE);
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


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Animated deselect fade
    [tableView deselectRowAtIndexPath:indexPath animated:true];

//    NSDictionary *user;
    XMPPUserMemoryStorageObject *user;
    switch (indexPath.section)
    {
        case ContactListSectionsOnline:
//            user = [[[AppDelegate appDelegate] rosterStorage] sortedAvailableUsersByName][indexPath.row];
//            break;

        case ContactListSectionsOffline:
//            user = [[[AppDelegate appDelegate] rosterStorage] sortedUnavailableUsersByName][indexPath.row];
            user = self.contactList[indexPath.section][indexPath.row];
            break;

        default: break;
    }

    // Show chat view
    debugLog(@"user: %@", user);
    debugLog(@"userJID: %@", [user jid]);
    debugLog(@"userAttributes: %@", [[user primaryResource] presence]);
//    [self showChatView:user];
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

    // Refresh
    [self refreshTableView];
}

- (void)xmppRoster:(XMPPRoster *)sender didReceivePresenceSubscriptionRequest:(XMPPPresence *)presence
{
    debugLog(@"roster received subscription request: %@", [[presence from] user]);
}

- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterPush:(XMPPIQ *)iq
{
    debugLog(@"roster received push: %@", iq);
}

- (void)xmppRoster:(XMPPRoster *)sender didReceiveRosterItem:(NSXMLElement *)item
{
    debugLog(@"roster received item: %@", item);
}


@end
