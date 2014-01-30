//
//  GCLoginViewController.m
//  GChat
//
//  Created by . Carlin on 1/29/14.
//  Copyright (c) 2014 Carlin. All rights reserved.
//

#import "GCLoginViewController.h"

    #define TEXT_CHECKBOX @"▢"
    #define TEXT_CHECKBOX_CHECKED @"\u2611"

@interface GCLoginViewController ()

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
    self.usernameTextField.placeholder = NSLocalizedString(@"LOGIN_USERNAME_FIELD_PLACEHOLDER", nil);
    self.passwordTextField.placeholder = NSLocalizedString(@"LOGIN_PASSWORD_FIELD_PLACEHOLDER", nil);
    [self.loginButton setTitle:NSLocalizedString(@"LOGIN_SIGNIN_BUTTON_TITLE", nil) forState:UIControlStateNormal];

    // Refresh persist button
    [self refreshPersistButton];
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
    // If persist, save credentials?
    if (self.persistButton.selected)
    {
        NSUserDefaults defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:self.usernameTextField.text forKey:CACHE_KEY_LOGIN_USERNAME];
        [defaults setObject:self.passwordTextField.text forKey:CACHE_KEY_LOGIN_PASSWORD];
        [defaults synchronize];
    }
}


@end
