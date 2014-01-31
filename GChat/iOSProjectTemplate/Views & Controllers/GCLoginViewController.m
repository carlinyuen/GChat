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

    - (IBAction)persistButtonTapped:(UIButton *)sender;
    - (IBAction)loginButtonTapped:(UIButton *)sender;

@end

@implementation GCLoginViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"LOGIN_VIEW_TITLE", nil);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Initial setup
    self.titleLabel.text = NSLocalizedString(@"LOGIN_VIEW_TITLE", nil);
    self.titleLabel.font = [UIFont fontWithName:(deviceOSVersionLessThan(@"7.0")
        ? FONT_NAME_THINNEST : FONT_NAME_THIN) size:FONT_SIZE_TITLE];
    self.usernameTextField.placeholder = NSLocalizedString(@"LOGIN_USERNAME_FIELD_PLACEHOLDER", nil);
    self.passwordTextField.placeholder = NSLocalizedString(@"LOGIN_PASSWORD_FIELD_PLACEHOLDER", nil);
    [self.loginButton setTitle:NSLocalizedString(@"LOGIN_SIGNIN_BUTTON_TITLE", nil) forState:UIControlStateNormal];
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


#pragma mark - Event Handlers

- (IBAction)persistButtonTapped:(UIButton *)sender
{
    self.persistButton.selected = !self.persistButton.selected;
    [self refreshPersistButton];
}

- (IBAction)loginButtonTapped:(UIButton *)sender
{
    // Save settings, will clear credentials later if not persisting
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.usernameTextField.text
        forKey:CACHE_KEY_LOGIN_USERNAME];
    [defaults setObject:self.passwordTextField.text
        forKey:CACHE_KEY_LOGIN_PASSWORD];
    [defaults setBool:self.persistButton.selected
        forKey:CACHE_KEY_LOGIN_PERSIST];
    [defaults synchronize];

    // Hide login
    [self dismissViewControllerAnimated:true completion:^{
        if ([[AppDelegate appDelegate] connect]) {
            debugLog(@"Show Contact List");
        }
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
