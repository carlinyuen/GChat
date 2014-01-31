/**
	@file	AppDelegate.h
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.

#import <UIKit/UIKit.h>

#import "XMPP.h"

@class AppViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

	@property (strong, nonatomic) UIWindow *window;

	@property (strong, nonatomic) AppViewController *viewController;

    @property (strong, nonatomic, readonly) XMPPStream *xmppStream;

    /** @brief Returns a reference to app delegate */
    + (AppDelegate *)appDelegate;

    /** @brief Attempt login to xmpp service */
    - (BOOL)connect;

    /** @brief Disconnect from xmpp service */
    - (void)disconnect;

@end
