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


@end
