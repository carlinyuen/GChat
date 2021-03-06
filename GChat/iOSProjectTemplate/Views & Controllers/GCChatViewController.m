//
//  GCChatViewController.m
//  GChat
//
//  Created by . Carlin on 1/30/14.
//  Copyright (c) 2014 Carlin. All rights reserved.
//

#import "GCChatViewController.h"

#import <QuartzCore/QuartzCore.h>

    #define KEY_CELL_ID @"MessageCell"
    #define KEY_HEADER_ID @"StatusCell"

    #define TIME_MANUAL_REFRESH 2

    #define SIZE_MARGIN 6
    #define SIZE_CORNER_RADIUS 6
    #define SIZE_BORDER_WIDTH 1
    #define SIZE_NAVBAR_INSET 64

    #define ALPHA_NAVBAR_COLOR 0.5

    #define KEY_INPUTVIEW_CONTAINER @"container"
    #define KEY_INPUTVIEW_TEXTVIEW @"text"
    #define KEY_INPUTVIEW_SENDBUTTON @"button"

@interface GCChatViewController () <
    UITableViewDataSource
    , UITableViewDelegate
    , UITextViewDelegate
    , UIScrollViewDelegate
>

    /** Tableview for messages */
    @property (weak, nonatomic) IBOutlet UITableView *tableView;
    @property (assign, nonatomic) BOOL refreshingTableView;

    /** Clickable title to change between nickname and email */
    @property (strong, nonatomic) UIButton *titleButton;

    /** View for showing contact status */
    @property (strong, nonatomic) UITextView *statusTextView;

    /** Sending message input */
    @property (strong, nonatomic) IBOutlet UIView *footerContainerView;
    @property (strong, nonatomic) UIView *footerView;
    @property (strong, nonatomic) UITextView *inputTextView;
    @property (strong, nonatomic) UIButton *sendButton;

    /** Input accessory view for when keyboard comes up */
    @property (strong, nonatomic) UIView *keyboardAccessoryView;
    @property (strong, nonatomic) UITextView *keyboardInputTextView;
    @property (strong, nonatomic) UIButton *keyboardSendButton;

    /** Storage for messages */
    @property (strong, nonatomic) NSMutableArray *messageList;

    /** For refreshing view */
    @property (strong, nonatomic) NSTimer *refreshTimer;

@end

@implementation GCChatViewController

- (id)initWithContact:(XMPPUserMemoryStorageObject *)contact
{
    self = [super initWithNibName:@"GCChatViewController" bundle:nil];
    if (self)
    {
        _contact = contact;

        _messageList = [NSMutableArray new];
       
        // Notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(messageReceived:)
            name:NOTIFICATION_MESSAGE_RECEIVED object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(contactPresenceChanged:)
            name:NOTIFICATION_PRESENCE_UPDATE object:nil];

        // Listen for keyboard appearances and disappearances
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(keyboardWillShow:)
            name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(keyboardDidShow:)
            name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(keyboardWillHide:)
            name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(keyboardDidHide:)
            name:UIKeyboardDidHideNotification object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Setup
    [self setupNavBar];
    [self setupFooterView];
    [self setupTableView];
    [self setupStatusView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    debugLog(@"chatVC viewWillAppear");
   
    // Reset navbar
    [self setupNavBar];

    // Fetch and show messages
    [self refreshTableView:self];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    debugLog(@"viewWillDisappear");

    // Stop editing when leaving
    [self endEditing];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // Update input view
    [self showFooterView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Setup

/** @brief Setup navbar */
- (void)setupNavBar
{
    // Clickable title for sorting
    self.titleButton = [[UIButton alloc] initWithFrame:CGRectMake(
        0, 0, CGRectGetWidth(self.view.frame) / 2, SIZE_MIN_TOUCH
    )];
    [self.titleButton setTitle:[self.contact displayName]
        forState:UIControlStateNormal];
    [self.titleButton setTitle:[[self.contact jid] bare]
        forState:UIControlStateHighlighted];
    [self.titleButton setTitleColor:UIColorFromHex(COLOR_HEX_BACKGROUND_DARK) forState:UIControlStateNormal];
    [self.titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
    self.titleButton.titleLabel.adjustsFontSizeToFitWidth = true;
    self.titleButton.titleLabel.font = [UIFont fontWithName:FONT_NAME_LIGHT size:FONT_SIZE_NAVBAR];
    self.navigationItem.titleView = self.titleButton;
}

/** @brief Setup status view */
- (void)setupStatusView
{
    CGFloat offset = (deviceOSVersionLessThan(iOS7) ? 0 : SIZE_MARGIN / 2);
    self.statusTextView = [[UITextView alloc] initWithFrame:CGRectMake(
        offset, offset,
        CGRectGetWidth(self.view.bounds) - offset * 2, SIZE_MIN_TOUCH)];
    self.statusTextView.textColor = [UIColor grayColor];
    self.statusTextView.font = [UIFont fontWithName:FONT_NAME_MEDIUM size:FONT_SIZE_CONTACT_STATUS];
    self.statusTextView.backgroundColor = [UIColor clearColor];
    self.statusTextView.editable = false;
    self.statusTextView.showsHorizontalScrollIndicator = false;
    self.statusTextView.showsVerticalScrollIndicator = false;

    if ([self.statusTextView respondsToSelector:@selector(setSelectable:)]) {
        self.statusTextView.selectable = true;
    }

    // Detect links and phone numbers
    self.statusTextView.dataDetectorTypes = UIDataDetectorTypeLink | UIDataDetectorTypePhoneNumber;
    self.statusTextView.scrollEnabled = false;  // Need this for bug in iOS 7 that makes detection wonky
}

/** @brief Setup footer view with message sending */
- (void)setupFooterView
{
    NSDictionary *views = [self createInputView];

    self.inputTextView = views[KEY_INPUTVIEW_TEXTVIEW];
    self.sendButton = views[KEY_INPUTVIEW_SENDBUTTON];
    self.footerView = views[KEY_INPUTVIEW_CONTAINER];
    self.footerView.backgroundColor
        = UIColorFromHex(COLOR_HEX_BACKGROUND_LIGHT);

    [self.footerContainerView addSubview:self.footerView];
    self.footerContainerView.backgroundColor
        = UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE);
    self.footerContainerView.alpha = 0;

    // Setup keyboard accessory view
    [self setupKeyboardView];
}

/** @brief Setup keyboard accessory view (basically a clone of footer) */
- (void)setupKeyboardView
{
    NSDictionary *views = [self createInputView];

    self.inputTextView.inputAccessoryView
        = self.keyboardAccessoryView
        = views[KEY_INPUTVIEW_CONTAINER];
    self.keyboardAccessoryView.backgroundColor
        = UIColorFromHex(COLOR_HEX_BACKGROUND_LIGHT);
    self.keyboardInputTextView = views[KEY_INPUTVIEW_TEXTVIEW];
    self.keyboardSendButton = views[KEY_INPUTVIEW_SENDBUTTON];
}

/** @brief Convenience method to create input view */
- (NSDictionary *)createInputView
{
    CGRect bounds = self.view.bounds;
    CGRect reference;

    // Containing view
    UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(bounds), SIZE_MIN_TOUCH)];
    containerView.backgroundColor = [UIColor clearColor];

    // Input field
    reference = containerView.bounds;
    UITextView *inputTextView = [[UITextView alloc] initWithFrame:CGRectMake(
        SIZE_MARGIN * 2, SIZE_MARGIN,
        CGRectGetWidth(reference) / 4 * 3,
        SIZE_MIN_TOUCH - SIZE_MARGIN * 2
    )];
    inputTextView.font = [UIFont fontWithName:FONT_NAME_LIGHT
        size:FONT_SIZE_CHAT_INPUT];
    inputTextView.showsHorizontalScrollIndicator = false;
    inputTextView.showsVerticalScrollIndicator = false;
    inputTextView.directionalLockEnabled = true;
    inputTextView.scrollsToTop = false;
    inputTextView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    inputTextView.layer.borderWidth = SIZE_BORDER_WIDTH;
    inputTextView.layer.cornerRadius = SIZE_CORNER_RADIUS;
    inputTextView.delegate = self;
    [containerView addSubview:inputTextView];

    // Send button
    reference = inputTextView.frame;
    UIButton *sendButton = [[UIButton alloc] initWithFrame:CGRectMake(
        CGRectGetMaxX(reference) + SIZE_MARGIN, 0,
        CGRectGetWidth(bounds) - CGRectGetMaxX(reference) - SIZE_MARGIN * 2, SIZE_MIN_TOUCH
    )];
    [sendButton setTitle:NSLocalizedString(@"CHAT_SEND_BUTTON_TITLE", nil)
        forState:UIControlStateNormal];
    [sendButton setTitleColor:UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE)
        forState:UIControlStateNormal];
    [sendButton setTitleColor:UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE_SELECTED)
        forState:UIControlStateHighlighted];
    [sendButton addTarget:self action:@selector(sendButtonTapped:)
        forControlEvents:UIControlEventTouchUpInside];
    [containerView addSubview:sendButton];

    return @{
        KEY_INPUTVIEW_SENDBUTTON: sendButton,
        KEY_INPUTVIEW_TEXTVIEW: inputTextView,
        KEY_INPUTVIEW_CONTAINER: containerView,
    };
}

/** @brief Setup tableview */
- (void)setupTableView
{
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    [self.tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:KEY_HEADER_ID];

    // Keyboard dismissing
    if ([self.tableView respondsToSelector:@selector(setKeyboardDismissMode:)]) {
        self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    }
    else    // Setup tap gesture for dismiss keyboard
    {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tableViewTapped:)];
        [self.tableView addGestureRecognizer:tap];
    }
}


#pragma mark - Class Methods

/** @brief Refreshes table view with messages */
- (void)refreshTableView:(id)sender
{
    // Don't do it if already refreshing
    if (self.refreshingTableView) {
        return;
    }

    debugLog(@"refreshTableView: %@", sender);

    self.refreshingTableView = true;

    // Setup to fetch messages from CoreData
    NSManagedObjectContext *moc = [[[AppDelegate appDelegate] messageArchiveStorage] mainThreadManagedObjectContext];
    NSEntityDescription *entityDescription = [NSEntityDescription
        entityForName:@"XMPPMessageArchiving_Message_CoreDataObject"
        inManagedObjectContext:moc];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"bareJidStr == %@", [[self.contact jid] bare]];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    [request setPredicate:predicate];

    // Fetch
    NSError *error;
    NSArray *messages = [moc executeFetchRequest:request error:&error];

    if (error)
    {
        self.refreshingTableView = false;

        // TODO: notify user

        return;
    }

    // Clear out message list and continue if my jid is setup
    NSString *myJIDStr = [[[[AppDelegate appDelegate] xmppStream] myJID] bare];
    if (!myJIDStr) {
        return;
    }

    [self.messageList removeAllObjects];

    // Add archived messages
    for (XMPPMessageArchiving_Message_CoreDataObject *message in messages)
    {
        [self addMessage:@{
            XMPP_TIMESTAMP: message.timestamp,
            XMPP_MESSAGE_TEXT: [message.message body],
            XMPP_MESSAGE_USERNAME: (message.isOutgoing)
                ? myJIDStr : message.bareJidStr,
        }];
    }

    // Remove flag
    self.refreshingTableView = false;

    debugLog(@"messages: %@", self.messageList);

    // Refresh tableview
    [self.tableView reloadData];

    // Update navbar color if show has changed
    [self refreshContactShowState];
   
    // Clear timer
    self.refreshTimer = nil;

    // Scroll to bottom
    [self scrollToBottom:false];
}

/** @brief Send message */
- (void)sendMessage:(NSString *)text
{
    // If message text exists
    if ([text length])
    {
        // Setup xmpp element
        XMPPMessage *message = [[XMPPMessage alloc] initWithType:XMPP_MESSAGE_TYPE_CHAT to:[self.contact jid]];
        [message addBody:text];

        // Send element
        [[[AppDelegate appDelegate] xmppStream] sendElement:message];

        // Insert into message list
        XMPPJID *myJID = [[[AppDelegate appDelegate] xmppStream] myJID];
        [self addMessage:@{
            XMPP_TIMESTAMP: [NSDate date],
            XMPP_MESSAGE_USERNAME: [myJID bare],
            XMPP_MESSAGE_TEXT: text,
        }];

        // Refresh tableview
        [self.tableView reloadData];
        [self scrollToBottom:true];
    }
}

/** @brief Add message to message list */
- (void)addMessage:(NSDictionary *)message
{
    if (message) {
        [self.messageList addObject:message];
    }
}

/** @brief Updates the position and shows the footer view */
- (void)showFooterView
{
    CGRect frame = self.footerView.frame;
    frame.origin.y = CGRectGetMaxY(self.view.frame) - CGRectGetHeight(frame);
    self.footerContainerView.frame = frame;

    [UIView animateWithDuration:ANIMATION_DURATION_FAST delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
            self.footerContainerView.alpha = 1;
        } completion:nil];
}

/** @brief Scroll tableview to bottom */
- (void)scrollToBottom:(BOOL)animated
{
    NSInteger section = [self.tableView numberOfSections] - 1;
    NSInteger row = [self.tableView numberOfRowsInSection:section] - 1;

    // Only scroll if has rows
    if (row > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath
                indexPathForItem:row inSection:section]
            atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

/** @brief End editing / hide keyboard */
- (void)endEditing
{
    [self.inputTextView resignFirstResponder];
    [self.keyboardInputTextView resignFirstResponder];
    [self.view endEditing:true];
}

/** @brief Refreshes indicator for contact show state */
- (void)refreshContactShowState
{
    NSString *show = [[[self.contact primaryResource] presence] show];
    debugLog(@"refreshContactState: %@", show);

    UIColor *color;
    if ([show isEqualToString:XMPP_PRESENCE_SHOW_AWAY]
        || [show isEqualToString:XMPP_PRESENCE_SHOW_AWAY_EXTENDED]) {
        color = UIColorFromHex(COLOR_HEX_SHOW_AWAY);
    } else if ([show isEqualToString:XMPP_PRESENCE_SHOW_BUSY]) {
        color = UIColorFromHex(COLOR_HEX_SHOW_BUSY);
    } else if (![self.contact primaryResource] || [[[[self.contact primaryResource] presence] type] isEqualToString:XMPP_PRESENCE_TYPE_OFFLINE]) {
        color = UIColorFromHex(COLOR_HEX_SHOW_OFFLINE);
    } else {
        color = UIColorFromHex(COLOR_HEX_SHOW_ONLINE);
    }

    [self updateNavBarColor:[color colorWithAlphaComponent:ALPHA_NAVBAR_COLOR]];
}

/** @brief Update navbar color */
- (void)updateNavBarColor:(UIColor *)color
{
    if (deviceOSVersionLessThan(iOS7)) {
        self.navigationController.navigationBar.tintColor = color;
    } else {
        self.navigationController.navigationBar.barTintColor = color;
    }
}

/** @brief Manual refresh */
- (void)manualRefresh
{
    

    [self scheduleRefresh:TIME_MANUAL_REFRESH overridePrevious:true];
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


#pragma mark - Event Handlers

/** @brief When send message button is tapped */
- (void)sendButtonTapped:(UIButton *)sender
{
    [self sendMessage:self.inputTextView.text];

    // Clear field
    self.inputTextView.text = @"";
    self.keyboardInputTextView.text = @"";
}

/** @brief When we get a message */
- (void)messageReceived:(NSNotification *)notification
{
    NSDictionary *message = notification.userInfo;
    debugLog(@"ChatView messageReceived: %@", message);

    // Only notify if not same user as we're viewing or if we're in background
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground
        || ![[[self.contact jid] bare] isEqualToString:message[XMPP_MESSAGE_USERNAME]])
    {

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
    else    // Message from currently viewing person
    {
        // Add message and display
        [self addMessage:@{
            XMPP_TIMESTAMP: message[XMPP_TIMESTAMP],
            XMPP_MESSAGE_USERNAME: message[XMPP_MESSAGE_USERNAME],
            XMPP_MESSAGE_TEXT: message[XMPP_MESSAGE_TEXT],
        }];

        // Reload tableview at that row
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath
                indexPathForItem:self.messageList.count - 1 inSection:0]
            ] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView endUpdates];

        // Scroll to bottom if already at bottom
        if (self.tableView.contentOffset.y >= (self.tableView.contentSize.height - self.tableView.frame.size.height) - SIZE_MIN_TOUCH) {
            [self scrollToBottom:true];
        }
    }
}

/** @brief When received notification that a contact's presence changed */
- (void)contactPresenceChanged:(NSNotification *)notification
{
    NSDictionary *presence = notification.userInfo;

    // Only bother if user is same as viewing
    if ([[[self.contact jid] bare] isEqualToString:presence[XMPP_PRESENCE_USERNAME]])
    {
        debugLog(@"contactPresenceChanged: %@", presence);

        // TODO: Notify user of change in status
    }
}

/** @brief Tableview tapped with gesture recognizer */
- (void)tableViewTapped:(UITapGestureRecognizer *)tap
{
    // Dismiss keyboard
    [self endEditing];
}

/** @brief When title button is tapped to change sorting */
- (void)titleTapped:(UIButton *)sender
{
    // Manual refresh
    [self manualRefresh];
}

/** @brief Keyboard will show */
- (void)keyboardWillShow:(NSNotification *)notification
{
    debugLog(@"keyboardWillShow");

    // Determine ending height and shrink view by that size
    NSDictionary *info = [notification userInfo];
    CGRect frame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];

    // Set insets for tableview
    UIEdgeInsets insets = self.tableView.contentInset;
    insets.bottom = CGRectGetHeight(frame) - CGRectGetHeight(self.keyboardAccessoryView.frame);
    insets.top = (deviceOSVersionLessThan(iOS7) ? 0 : SIZE_NAVBAR_INSET) - [self tableView:self.tableView heightForHeaderInSection:0];

    __block GCChatViewController *this = self;
    [UIView animateWithDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue] delay:0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
            this.tableView.contentInset = insets;
            this.footerView.alpha = 0;
            [this scrollToBottom:true];
        } completion:nil];
}

/** @brief Keyboard did show */
- (void)keyboardDidShow:(NSNotification *)notification
{
    debugLog(@"keyboardDidShow");

    // Switch first responder to keyboard input
    [self.keyboardInputTextView becomeFirstResponder];
}

/** @brief Keyboard will hide */
- (void)keyboardWillHide:(NSNotification *)notification
{
    debugLog(@"keyboardWillHide");

    self.footerView.alpha = 1;

    // Animate back to zero
    __block GCChatViewController *this = self;
    [UIView animateWithDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue] delay:0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
            this.tableView.contentInset = UIEdgeInsetsMake((deviceOSVersionLessThan(iOS7) ? 0 : SIZE_NAVBAR_INSET), 0, 0, 0);
        } completion:nil];
}

/** @brief Keyboard did hide */
- (void)keyboardDidHide:(NSNotification *)notification
{
    debugLog(@"keyboardDidHide");

    [self scrollToBottom:true];
}


#pragma mark - Protocols
#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messageList.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *status = [[[self.contact primaryResource] presence] status];

    // If no status, no header
    if (!status || !status.length) {
        return 0;
    }

    // Calculate height of text, need to reset width
    CGFloat offset = (deviceOSVersionLessThan(iOS7) ? 0 : SIZE_MARGIN);
    CGRect frame = self.statusTextView.frame;
    self.statusTextView.text = [[[self.contact primaryResource] presence] status];
    frame.size.width = CGRectGetWidth(self.view.bounds) - offset;
    frame.size.height = CGFLOAT_MAX;
    self.statusTextView.frame = frame;
    [self.statusTextView sizeToFit];

    return CGRectGetHeight(self.statusTextView.frame) + offset;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:KEY_CELL_ID];

    // Create cell if DNE
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:KEY_CELL_ID];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }

    // Get data to populate with
    NSDictionary *data = self.messageList[indexPath.row];

    // Large text field
    cell.textLabel.text = data[XMPP_MESSAGE_TEXT];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.textLabel.font = [UIFont fontWithName:FONT_NAME_LIGHT size:FONT_SIZE_CHAT_INPUT];

    // Detailed text field
    cell.detailTextLabel.text = ([data[XMPP_MESSAGE_USERNAME] isEqualToString:[[self.contact jid] bare]]) ? [self.contact displayName] : NSLocalizedString(@"CHAT_FROM_ME_TEXT", nil);
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.textColor = UIColorFromHex(COLOR_HEX_BLACK_TRANSPARENT);
    cell.detailTextLabel.font = [UIFont fontWithName:FONT_NAME_MEDIUM size:FONT_SIZE_CONTACT_STATUS];

    return cell;
}

- (UITableViewHeaderFooterView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UITableViewHeaderFooterView *view = [tableView dequeueReusableHeaderFooterViewWithIdentifier:KEY_HEADER_ID];

    view.contentView.backgroundColor = UIColorFromHex(COLOR_HEX_BACKGROUND_LIGHT);

    // Add textview for status
    [view addSubview:self.statusTextView];

    return view;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Animated deselect fade
    [tableView deselectRowAtIndexPath:indexPath animated:true];
}


#pragma mark - UIScrollView

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Don't let message input scroll horizontally
    if (scrollView == self.inputTextView)
    {
        CGPoint offset = self.inputTextView.contentOffset;
        offset.x = 0;
        self.inputTextView.contentOffset = offset;
    }
}


#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
    // Make both fields match
    if (textView == self.inputTextView) {
        self.keyboardInputTextView.text = textView.text;
    } else if (textView == self.keyboardInputTextView) {
        self.inputTextView.text = textView.text;
    }
}


@end
