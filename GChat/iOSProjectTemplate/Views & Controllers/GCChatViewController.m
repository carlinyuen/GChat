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

    @property (weak, nonatomic) IBOutlet UITableView *tableView;

    /** Clickable title to change between nickname and email */
    @property (strong, nonatomic) UIButton *titleButton;

    /** Sending message input */
    @property (strong, nonatomic) UIView *footerView;
    @property (strong, nonatomic) UITextView *inputTextView;
    @property (strong, nonatomic) UIButton *sendButton;

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
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Title
    self.title = [self.contact displayName];

    // Setup
    [self setupNavBar];
    [self setupFooterView];
    [self setupTableView];
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
    self.footerView = [[UIView alloc] initWithFrame:CGRectMake(
        0, 0, CGRectGetWidth(bounds), SIZE_MIN_TOUCH
    )];
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
}

/** @brief Setup tableview */
- (void)setupTableView
{
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    [self.tableView registerClass:[UITableViewCell class]
        forCellReuseIdentifier:KEY_CELL_ID];

    self.tableView.tableFooterView = self.footerView;
}


#pragma mark - Class Methods

/** @brief Send message */
- (void)sendMessage:(NSString *)text
{
    // If message text exists
    if ([text length])
    {
        // Setup xmpp element
        NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
        [body setStringValue:text];
        NSXMLElement *message = [NSXMLElement elementWithName:@"message"];
        [message addAttributeWithName:@"type" stringValue:@"chat"];
        [message addAttributeWithName:@"to" stringValue:[self.contact displayName]];
        [message addChild:body];

        // Send element
        [[[AppDelegate appDelegate] xmppStream] sendElement:message];

        // Clear and refresh
        self.inputTextView.text = @"";

        [self.messageList addObject:@{
            @"message": text,
            @"timestamp": [NSDate date],
            @"sender": @"you",
        }];
        [self.tableView reloadData];
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
}

/** @brief When title button is tapped to change sorting */
- (void)titleTapped:(UIButton *)sender
{
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

    cell.textLabel.text = self.messageList[indexPath.row][@"message"];

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
