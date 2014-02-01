//
//  GCLoginViewController.m
//  GChat
//
//  Created by . Carlin on 1/29/14.
//  Copyright (c) 2014 Carlin. All rights reserved.
//

#import "GCLoginViewController.h"

#import "AppDelegate.h"

    #define TEXT_CHECKBOX @"▢"
    #define TEXT_CHECKBOX_CHECKED @"\u2611"

@interface GCLoginViewController () <
    UITextFieldDelegate
>

    @property (weak, nonatomic) IBOutlet UILabel *titleLabel;
    @property (weak, nonatomic) IBOutlet UITextField *usernameTextField;
    @property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
    @property (weak, nonatomic) IBOutlet UIButton *persistButton;
    @property (weak, nonatomic) IBOutlet UIButton *loginButton;

    @property (strong, nonatomic) UIActivityIndicatorView *loadingIndicator;

    - (IBAction)persistButtonTapped:(UIButton *)sender;
    - (IBAction)loginButtonTapped:(UIButton *)sender;

@end

@implementation GCLoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.title = NSLocalizedString(@"LOGIN_VIEW_TITLE", nil);

        // Notifications
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(connectionStatusChanged:)
            name:NOTIFICATION_CONNECTION_CHANGED object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Initial setup of fields & buttons
    self.titleLabel.text = NSLocalizedString(@"LOGIN_VIEW_TITLE", nil);
    self.titleLabel.font = [UIFont fontWithName:(deviceOSVersionLessThan(@"7.0")
        ? FONT_NAME_THINNEST : FONT_NAME_THIN) size:FONT_SIZE_TITLE];
    self.usernameTextField.placeholder = NSLocalizedString(@"LOGIN_USERNAME_FIELD_PLACEHOLDER", nil);
    self.passwordTextField.placeholder = NSLocalizedString(@"LOGIN_PASSWORD_FIELD_PLACEHOLDER", nil);
    [self.loginButton setTitle:NSLocalizedString(@"LOGIN_SIGNIN_BUTTON_TITLE", nil) forState:UIControlStateNormal];

    // Loading indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.loadingIndicator.color = UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE);
    self.loadingIndicator.center = self.view.center;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
   
    // Refresh persist button
    self.persistButton.selected = !![[NSUserDefaults standardUserDefaults]
        objectForKey:CACHE_KEY_LOGIN_USERNAME];
    [self refreshPersistButton];

    // Focus on username field
    [self.usernameTextField becomeFirstResponder];
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


#pragma mark - Class Methods

/** @brief Refresh the persist button with checkbox characters */
- (void)refreshPersistButton
{
    [self.persistButton setTitle:[NSString stringWithFormat:@"%@ %@",
            (self.persistButton.selected
                ? TEXT_CHECKBOX_CHECKED : TEXT_CHECKBOX),
            NSLocalizedString(@"LOGIN_PERSIST_BUTTON_TITLE", nil)]
        forState:UIControlStateNormal];
}

/** @brief Validate input, returns an array of errors */
- (NSArray *)inputValidationErrors
{
    NSString *username = self.usernameTextField.text;
    NSString *password = self.passwordTextField.text;
    NSMutableArray *errors = [NSMutableArray new];

    if (![username length]) {
        [errors addObject:NSLocalizedString(@"ERROR_BLANK_USERNAME", nil)];
    }
    if (![password length]) {
        [errors addObject:NSLocalizedString(@"ERROR_BLANK_PASSWORD", nil)];
    }
    if (![[NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", REGEX_EMAIL_VERIFICATION] evaluateWithObject:username]) {
        [errors addObject:NSLocalizedString(@"ERROR_INVALID_EMAIL", nil)];
    }

    return errors;
}

- (void)showLoadingIndicator:(BOOL)show
{
    if (show) {
        [self.view addSubview:self.loadingIndicator];
        [self.loadingIndicator startAnimating];
    }
    [UIView animateWithDuration:ANIMATION_DURATION_FAST delay:0
        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
        animations:^{
            self.loadingIndicator.alpha = (show ? 1 : 0);
        } completion:^(BOOL finished) {
            if (!show) {
                [self.loadingIndicator stopAnimating];
                [self.loadingIndicator removeFromSuperview];
            }
        }];
}


#pragma mark - Event Handlers

- (IBAction)persistButtonTapped:(UIButton *)sender
{
    self.persistButton.selected = !self.persistButton.selected;
    [self refreshPersistButton];
}

- (IBAction)loginButtonTapped:(UIButton *)sender
{
    // Validate input
    NSArray *validationErrors = [self inputValidationErrors];
    if (!validationErrors.count)
    {
        // Try to connect
        [[AppDelegate appDelegate] connectWithUsername:self.usernameTextField.text andPassword:self.passwordTextField.text];
    }
    else {    // Display errors
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"POPUP_ERROR_TITLE", nil)
            message:[validationErrors componentsJoinedByString:@"\n"]
            delegate:nil
            cancelButtonTitle:NSLocalizedString(@"POPUP_CONFIRM_BUTTON_TITLE", nil)
            otherButtonTitles:nil] show];
    }
}

/** @brief When connection status to xmpp service changes */
- (void)connectionStatusChanged:(NSNotification *)notification
{
    // If connected, dismiss login screen
    if ([notification.userInfo[@"status"] isEqualToString:@"connected"])
    {
        [self showLoadingIndicator:false];

        // Save settings, will clear credentials later if not persisting
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:self.usernameTextField.text
            forKey:CACHE_KEY_LOGIN_USERNAME];
        [defaults setObject:self.passwordTextField.text
            forKey:CACHE_KEY_LOGIN_PASSWORD];
        [defaults setBool:self.persistButton.selected
            forKey:CACHE_KEY_LOGIN_PERSIST];
        [defaults synchronize];

        // Dismiss
        [self dismissViewControllerAnimated:true completion:nil];
    }

    // If connection times out
    else if ([notification.userInfo[@"status"] isEqualToString:@"timeout"])
    {
        [self showLoadingIndicator:false];

        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"POPUP_ERROR_TITLE", nil)
            message:NSLocalizedString(@"ERROR_CONNECTION_TIMEOUT", nil)
            delegate:nil
            cancelButtonTitle:NSLocalizedString(@"POPUP_CONFIRM_BUTTON_TITLE", nil)
            otherButtonTitles:nil] show];
    }

    // If connecting, show spinner
    else if ([notification.userInfo[@"status"] isEqualToString:@"connecting"])
    {
        [self showLoadingIndicator:true];
    }
}


#pragma mark - Protocols
#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == self.usernameTextField) {
        [self.passwordTextField becomeFirstResponder];
    } else if (textField == self.passwordTextField) {
        [self loginButtonTapped:self.loginButton];
    }

    return true;
}


@end
