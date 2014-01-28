/**
	@file	AppDelegate.m
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.

#import "AppDelegate.h"

#import "AppViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
    // Override point for customization after application launch.
	self.viewController = [[AppViewController alloc] initWithNibName:@"AppViewController" bundle:nil];
	self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:self.viewController];
    [self.window makeKeyAndVisible];
    return YES;
}

/** @brief Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game. 
*/
- (void)applicationWillResignActive:(UIApplication *)application
{
}

/** @brief Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
*/
- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

/** @brief Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
*/
- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

/** @brief Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
*/
- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

/** @brief Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
*/
- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
