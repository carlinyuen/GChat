//
//  GCWebViewController.m
//  GChat
//
//  Created by . Carlin on 2/6/14.
//  Copyright (c) 2014 Carlin. All rights reserved.
//

#import "GCWebViewController.h"

@interface GCWebViewController ()

    @property (weak, nonatomic) IBOutlet UIWebView *webView;
    @property (weak, nonatomic) IBOutlet UIToolbar *toolBar;
    @property (weak, nonatomic) IBOutlet UIBarButtonItem *backButton;
    @property (weak, nonatomic) IBOutlet UIBarButtonItem *nextButton;

    - (IBAction)closeButtonTapped:(id)sender;
    - (IBAction)nextButtonTapped:(id)sender;
    - (IBAction)backButtonTapped:(id)sender;

@end

@implementation GCWebViewController

- (id)initWithURLString:(NSString *)urlString
{
    self = [super initWithNibName:@"GCWebViewController" bundle:nil];
    if (self) {
        _urlString = urlString;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Setup webview
    self.webView.delegate = self;

    // Flip the back button
    UIView *back = [self.backButton valueForKey:@"view"];
    back.transform = CGAffineTransformMakeScale(-1, 1);

    [self refresh];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Class Methods

/** @brief Refresh webview with current urlString */
- (void)refresh
{
    [self.webView loadRequest:[NSURLRequest
        requestWithURL:[NSURL URLWithString:self.urlString]]];
}


#pragma mark - Event Handlers

- (IBAction)closeButtonTapped:(id)sender {
    [self dismissViewControllerAnimated:true completion:nil];
}

- (IBAction)nextButtonTapped:(id)sender {
    if (self.webView.canGoForward) {
        [self.webView goForward];
    }
}

- (IBAction)backButtonTapped:(id)sender {
    if (self.webView.canGoBack) {
        [self.webView goBack];
    }
}


#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (self.delegate) {
        if ([self.delegate respondsToSelector:@selector(webViewController:shouldStartLoadWithRequest:navigationType:)]) {
            return [self.delegate webViewController:self shouldStartLoadWithRequest:request navigationType:navigationType];
        }
    }

    // Default to yes
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    // Update back/forward buttons based
    self.backButton.enabled = self.webView.canGoBack;
    self.nextButton.enabled = self.webView.canGoForward;
}


@end
