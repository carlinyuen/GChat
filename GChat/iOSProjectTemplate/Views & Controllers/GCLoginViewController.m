//
//  GCLoginViewController.m
//  GChat
//
//  Created by . Carlin on 1/29/14.
//  Copyright (c) 2014 Carlin. All rights reserved.
//

#import "GCLoginViewController.h"

#import "AppDelegate.h"
#import "AppViewController.h"
#import "GCWebViewController.h"

    #define TEXT_CHECKBOX @"▢"
    #define TEXT_CHECKBOX_CHECKED @"\u2611"

    #define URL_TWOFACTOR_SUPPORT @"https://support.google.com/accounts/answer/185833"
    #define URL_GOOGLEAPPS_SUPPORT @"http://www.olark.com/gtalk/check_srv"

@interface GCLoginViewController () <
    UITextFieldDelegate
>

    /** UI elements */
    @property (weak, nonatomic) IBOutlet UILabel *titleLabel;
    @property (weak, nonatomic) IBOutlet UITextField *usernameTextField;
    @property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
    @property (weak, nonatomic) IBOutlet UIButton *persistButton;
    @property (weak, nonatomic) IBOutlet UIButton *loginButton;
    @property (weak, nonatomic) IBOutlet UIButton *twoFactorButton;
    @property (weak, nonatomic) IBOutlet UIButton *googleAppsButton;

    /** Loading indicator when trying to sign in */
    @property (strong, nonatomic) UIActivityIndicatorView *loadingIndicator;

    /** Flag to prevent multiple presentations at the same time */
    @property (assign, nonatomic) BOOL isPresentingView;

    /** Actions */
    - (IBAction)persistButtonTapped:(UIButton *)sender;
    - (IBAction)loginButtonTapped:(UIButton *)sender;
    - (IBAction)viewTapped:(UITapGestureRecognizer *)sender;

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
    self.titleLabel.font = [UIFont fontWithName:(deviceOSVersionLessThan(iOS7)
        ? FONT_NAME_THINNEST : FONT_NAME_THIN) size:FONT_SIZE_TITLE];

    // Username / email field
    self.usernameTextField.placeholder = NSLocalizedString(@"LOGIN_USERNAME_FIELD_PLACEHOLDER", nil);
    [self.usernameTextField setKeyboardAppearance:UIKeyboardAppearanceAlert];

    // Password field
    self.passwordTextField.placeholder = NSLocalizedString(@"LOGIN_PASSWORD_FIELD_PLACEHOLDER", nil);
    [self.passwordTextField setKeyboardAppearance:UIKeyboardAppearanceAlert];

    // Login button
    [self.loginButton setTitle:NSLocalizedString(@"LOGIN_SIGNIN_BUTTON_TITLE", nil)
        forState:UIControlStateNormal];
    [self.loginButton setTitleColor:UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE)
        forState:UIControlStateNormal];
    [self.loginButton setTitleColor:UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE_SELECTED)
        forState:UIControlStateHighlighted];

    // Two factor auth button
    [self.twoFactorButton setTitle:NSLocalizedString(@"LOGIN_TWOFACTOR_BUTTON_TITLE", nil) forState:UIControlStateNormal];
    [self.twoFactorButton setTitleColor:UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE)
        forState:UIControlStateNormal];
    [self.twoFactorButton setTitleColor:UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE_SELECTED)
        forState:UIControlStateHighlighted];
    [self.twoFactorButton addTarget:self action:@selector(twoFactorButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // Google Apps button
    [self.googleAppsButton setTitle:NSLocalizedString(@"LOGIN_GOOGLEAPPS_BUTTON_TITLE", nil) forState:UIControlStateNormal];
    [self.googleAppsButton setTitleColor:UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE)
        forState:UIControlStateNormal];
    [self.googleAppsButton setTitleColor:UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE_SELECTED)
        forState:UIControlStateHighlighted];
    [self.googleAppsButton addTarget:self action:@selector(googleAppsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // Loading indicator
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.loadingIndicator.color = UIColorFromHex(COLOR_HEX_APPLE_BUTTON_BLUE);
    self.loadingIndicator.frame = self.loginButton.frame;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
   
    // Refresh persist button
    self.persistButton.selected = [[NSUserDefaults standardUserDefaults]
        boolForKey:CACHE_KEY_LOGIN_PERSIST];
    [self refreshPersistButton];

    // Put last login in and focus on username field
    self.usernameTextField.text = [[NSUserDefaults standardUserDefaults] objectForKey:CACHE_KEY_LOGIN_USERNAME];
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
            self.loginButton.alpha = (show ? 0 : 1);
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
    // Hide keyboard to also show other options in case people didn't see them on 3.5" screens
    [self.view endEditing:true];

    // Validate input
    NSArray *validationErrors = [self inputValidationErrors];
    if (!validationErrors.count)
    {
        // Try to connect
        [[AppDelegate appDelegate] connectWithUsername:self.usernameTextField.text andPassword:self.passwordTextField.text];
    }
    else    // Display errors
    {
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
    NSString *status = notification.userInfo[XMPP_STATUS];

    // If connected, dismiss login screen
    if ([status isEqualToString:XMPP_CONNECTION_OK])
    {
        [self showLoadingIndicator:false];

        // Save login settings
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:self.usernameTextField.text
            forKey:CACHE_KEY_LOGIN_USERNAME];

        // Save password if persisting
        if (self.persistButton.selected)
        {
            [defaults setObject:self.passwordTextField.text
                forKey:CACHE_KEY_LOGIN_PASSWORD];
            [defaults setBool:self.persistButton.selected
                forKey:CACHE_KEY_LOGIN_PERSIST];
        }
        [defaults synchronize];

        // Dismiss
//        [[[AppDelegate appDelegate] viewController] manualPullToRefresh];
        [self dismissViewControllerAnimated:true completion:nil];
    }

    // If connection times out
    else if ([status isEqualToString:XMPP_CONNECTION_ERROR_TIMEOUT])
    {
        [self showLoadingIndicator:false];

        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"POPUP_ERROR_TITLE", nil)
            message:NSLocalizedString(@"ERROR_CONNECTION_TIMEOUT", nil)
            delegate:nil
            cancelButtonTitle:NSLocalizedString(@"POPUP_CONFIRM_BUTTON_TITLE", nil)
            otherButtonTitles:nil] show];
    }

    // If authentication error
    else if ([status isEqualToString:XMPP_CONNECTION_ERROR_AUTH])
    {
        [self showLoadingIndicator:false];

        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"POPUP_ERROR_TITLE", nil)
            message:NSLocalizedString(@"ERROR_CONNECTION_AUTH", nil)
            delegate:nil
            cancelButtonTitle:NSLocalizedString(@"POPUP_CONFIRM_BUTTON_TITLE", nil)
            otherButtonTitles:nil] show];
    }

    // If connecting, show spinner
    else if ([status isEqualToString:XMPP_CONNECTION_CONNECTING])
    {
        [self showLoadingIndicator:true];
    }
}

/** @brief View tapped */
- (IBAction)viewTapped:(UITapGestureRecognizer *)gesture
{
    [self.view endEditing:true];
}

/** @brief Two-Factor Auth Button Pressed */
- (void)twoFactorButtonTapped:(UIButton *)sender
{
    // Only present one at a time
    if (self.isPresentingView) {
        return;
    }

    // Create and present webview
    self.isPresentingView = true;
    GCWebViewController *webVC = [[GCWebViewController alloc] initWithURLString:URL_TWOFACTOR_SUPPORT];
    __block GCLoginViewController *this = self;
    [self presentViewController:webVC animated:true completion:^{
        this.isPresentingView = false;
    }];
}

/** @brief Google Apps Button Pressed */
- (void)googleAppsButtonTapped:(UIButton *)sender
{
    // Only present one at a time
    if (self.isPresentingView) {
        return;
    }

    // Create and present webview
    self.isPresentingView = true;
    GCWebViewController *webVC = [[GCWebViewController alloc] initWithURLString:URL_GOOGLEAPPS_SUPPORT];
    __block GCLoginViewController *this = self;
    [self presentViewController:webVC animated:true completion:^{
        this.isPresentingView = false;
    }];
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
