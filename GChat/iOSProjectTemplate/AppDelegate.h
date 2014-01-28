/**
	@file	AppDelegate.h
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.

#import <UIKit/UIKit.h>

@class AppViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

	@property (strong, nonatomic) UIWindow *window;

	@property (strong, nonatomic) AppViewController *viewController;

@end
