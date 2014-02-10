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

    #define SIZE_MARGIN 6
    #define SIZE_CORNER_RADIUS 6
    #define SIZE_BORDER_WIDTH 1

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

    /** Sending message input */
    @property (strong, nonatomic) IBOutlet UIView *footerView;
    @property (strong, nonatomic) UITextView *inputTextView;
    @property (strong, nonatomic) UIButton *sendButton;
    @property (weak, nonatomic) IBOutlet NSLayoutConstraint *footerBottomConstraint;

    /** Storage for messages */
    @property (strong, nonatomic) NSMutableArray *messageList;

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
            selector:@selector(keyboardWillHide:)
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
    [self.titleButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [self.titleButton setTitleColor:[UIColor blackColor] forState:UIControlStateHighlighted];
    self.titleButton.titleLabel.adjustsFontSizeToFitWidth = true;
    self.titleButton.titleLabel.font = (deviceOSVersionLessThan(iOS7))
        ? [UIFont fontWithName:FONT_NAME_LIGHT size:FONT_SIZE_NAVBAR]
        : [UIFont fontWithName:FONT_NAME_THIN size:FONT_SIZE_NAVBAR];
    self.navigationItem.titleView = self.titleButton;
}

/** @brief Setup footer view with message sending */
- (void)setupFooterView
{
    CGRect bounds = self.view.bounds;
    CGRect reference;

    // Containing view
    self.footerView.backgroundColor = UIColorFromHex(COLOR_HEX_BACKGROUND_LIGHT);

    // Input field
    self.inputTextView = [[UITextView alloc] initWithFrame:CGRectMake(
        SIZE_MARGIN * 2, SIZE_MARGIN,
        CGRectGetWidth(bounds) / 4 * 3,
        SIZE_MIN_TOUCH - SIZE_MARGIN * 2
    )];
    self.inputTextView.font = [UIFont fontWithName:FONT_NAME_LIGHT
        size:FONT_SIZE_CHAT_INPUT];
    self.inputTextView.showsHorizontalScrollIndicator = false;
    self.inputTextView.showsVerticalScrollIndicator = false;
    self.inputTextView.directionalLockEnabled = true;
    self.inputTextView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.inputTextView.layer.borderWidth = SIZE_BORDER_WIDTH;
    self.inputTextView.layer.cornerRadius = SIZE_CORNER_RADIUS;
    self.inputTextView.delegate = self;
    [self.footerView addSubview:self.inputTextView];

    // Send button
    reference = self.inputTextView.frame;
    self.sendButton = [[UIButton alloc] initWithFrame:CGRectMake(
        CGRectGetMaxX(reference) + SIZE_MARGIN, 0,
        CGRectGetWidth(bounds) - CGRectGetMaxX(reference) - SIZE_MARGIN * 2, SIZE_MIN_TOUCH
    )];
    [self.sendButton setTitle:NSLocalizedString(@"CHAT_SEND_BUTTON_TITLE", nil)
        forState:UIControlStateNormal];
    [self.sendButton setTitleColor:UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE)
        forState:UIControlStateNormal];
    [self.sendButton addTarget:self action:@selector(sendButtonTapped:)
        forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:self.sendButton];

    // Set to hidden first
    self.footerView.alpha = 0;
}

/** @brief Setup tableview */
- (void)setupTableView
{
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
}


#pragma mark - Class Methods

/** @brief Refreshes table view with messages */
- (void)refreshTableView:(id)sender
{
    // Don't do it if already refreshing
    if (self.refreshingTableView) {
        return;
    }

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

    // Do this on background thread
    __block GCChatViewController *this = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        // Add archived messages
        for (XMPPMessageArchiving_Message_CoreDataObject *message in messages)
        {
            if (this) {
                [this addMessage:@{
                    XMPP_TIMESTAMP: message.timestamp,
                    XMPP_MESSAGE_TEXT: [message.message body],
                    XMPP_MESSAGE_USERNAME: (message.isOutgoing)
                        ? myJIDStr : message.bareJidStr,
                }];
            }
        }

        // Back to main thread
        dispatch_sync(dispatch_get_main_queue(), ^
        {
            if (this)
            {
                // Remove flag
                this.refreshingTableView = false;

                debugLog(@"messages: %@", this.messageList);

                // Refresh tableview
                [this.tableView reloadData];

                // Scroll to bottom
                [this scrollToBottom:false];
            }
        });
    });
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

        // Clear and refresh
        self.inputTextView.text = @"";
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
    self.footerView.frame = frame;

    [UIView animateWithDuration:ANIMATION_DURATION_FAST delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:^{
            self.footerView.alpha = 1;
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


#pragma mark - Event Handlers

/** @brief When send message button is tapped */
- (void)sendButtonTapped:(UIButton *)sender
{
    [self sendMessage:self.inputTextView.text];
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

/** @brief When title button is tapped to change sorting */
- (void)titleTapped:(UIButton *)sender
{
}

/** @brief Keyboard will show */
- (void)keyboardWillShow:(NSNotification *)notification
{
    // Determine ending height and shrink view by that size
    NSDictionary *info = [notification userInfo];
    CGRect frame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];

    [UIView animateWithDuration:.2 delay:0
        options:UIViewAnimationOptionBeginFromCurrentState
            | UIViewAnimationCurveEaseOut
        animations:^{
            self.footerBottomConstraint.constant = frame.size.height;
            [self.view layoutIfNeeded];
            [self scrollToBottom:true];
        } completion:nil];
}

/** @brief Keyboard will hide */
- (void)keyboardWillHide:(NSNotification *)notification
{
    // Animate back to zero
    [UIView animateWithDuration:ANIMATION_DURATION_KEYBOARD delay:0
        options:UIViewAnimationOptionBeginFromCurrentState
            | UIViewAnimationCurveEaseOut
        animations:^{
            self.footerBottomConstraint.constant = 0;
            [self.view layoutIfNeeded];
        } completion:nil];
}


#pragma mark - Protocols
#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messageList.count;
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


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Animated deselect fade
    [tableView deselectRowAtIndexPath:indexPath animated:true];
}


#pragma mark - UIScrollView

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == self.inputTextView)
    {
        CGPoint offset = self.inputTextView.contentOffset;
        offset.x = 0;
        self.inputTextView.contentOffset = offset;
    }
}


@end
