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
>

    @property (weak, nonatomic) IBOutlet UITableView *tableView;

    @property (strong, nonatomic) UIView *footerView;
    @property (strong, nonatomic) UITextView *inputTextView;
    @property (strong, nonatomic) UIButton *sendButton;

@end

@implementation GCChatViewController

- (id)initWithContact:(NSDictionary *)contact
{
    self = [super initWithNibName:@"GCChatViewController" bundle:nil];
    if (self)
    {
        _contactInfo = contact;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Title
    self.title = @"Carlin Yuen";

    // Setup
    [self setupFooterView];
    [self setupTableView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Setup

/** @brief Setup footer view with message sending */
- (void)setupFooterView
{
    CGRect bounds = self.view.bounds;

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
    self.inputTextView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    self.inputTextView.layer.borderWidth = SIZE_BORDER_WIDTH;
    self.inputTextView.layer.cornerRadius = SIZE_CORNER_RADIUS;
    if (deviceOSVersionLessThan(@"7.0")) {
        self.inputTextView.contentInset = UIEdgeInsetsMake(
            SIZE_MARGIN, SIZE_MARGIN, SIZE_MARGIN, SIZE_MARGIN
        );
    } else {
        self.inputTextView.textContainerInset = UIEdgeInsetsMake(
            SIZE_MARGIN, SIZE_MARGIN, SIZE_MARGIN, SIZE_MARGIN
        );
    }
    [self.footerView addSubview:self.inputTextView];

    // Send button
    CGRect reference = self.inputTextView.frame;
    self.sendButton = [[UIButton alloc] initWithFrame:CGRectMake(
        CGRectGetMaxX(reference) + SIZE_MARGIN, 0,
        CGRectGetWidth(bounds) - CGRectGetMaxX(reference) - SIZE_MARGIN * 2, SIZE_MIN_TOUCH
    )];
    [self.sendButton setTitle:NSLocalizedString(@"CHAT_SEND_BUTTON_TITLE", nil)
        forState:UIControlStateNormal];
    [self.sendButton setTitleColor:UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE)
        forState:UIControlStateNormal];
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


#pragma mark - Protocols
#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:KEY_CELL_ID];

    return cell;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Animated deselect fade
    [tableView deselectRowAtIndexPath:indexPath animated:true];
}


@end
