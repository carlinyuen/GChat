//
//  GCWebViewController.h
//  GChat
//
//  Created by . Carlin on 2/6/14.
//  Copyright (c) 2014 Carlin. All rights reserved.
//

#import <UIKit/UIKit.h>

@class GCWebViewController;
@protocol GCWebViewControllerDelegate <NSObject>
    @optional
    - (BOOL)webViewController:(GCWebViewController *)vc
        shouldStartLoadWithRequest:(NSURLRequest *)request
        navigationType:(UIWebViewNavigationType)navigationType;
@end

@interface GCWebViewController : UIViewController <
    UIWebViewDelegate
>

    /** String for url to load */
    @property (nonatomic, copy) NSString *urlString;

    @property (weak, nonatomic) id<GCWebViewControllerDelegate> delegate;

    /** @brief Inits view controller with urlString already set */
    - (id)initWithURLString:(NSString *)urlString;

    /** @brief Refresh webview with current urlString */
    - (void)refresh;

@end
