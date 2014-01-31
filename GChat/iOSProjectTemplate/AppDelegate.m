/**
	@file	AppDelegate.m
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.

#import "AppDelegate.h"

#import "AppViewController.h"

    #define TIME_CONNECTION_TIMEOUT 30  // In seconds

    #define GCHAT_DOMAIN @"talk.google.com"

@interface AppDelegate() <
    XMPPStreamDelegate
>

    @property (strong, nonatomic, readwrite) XMPPStream *xmppStream;

@end

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
    [self disconnect];
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
    [self connect];
}

/** @brief Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
*/
- (void)applicationWillTerminate:(UIApplication *)application
{
    // Clear credentials
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:CACHE_KEY_LOGIN_PERSIST])
    {
        [defaults removeObjectForKey:CACHE_KEY_LOGIN_USERNAME];
        [defaults removeObjectForKey:CACHE_KEY_LOGIN_PASSWORD];
    }
    [defaults synchronize];
}

/** @brief Returns a reference to app delegate */
+ (AppDelegate *)appDelegate
{
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}


#pragma mark - XMPP Setup

- (void)setupStream
{
    self.xmppStream = [XMPPStream new];
    [self.xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (void)goOnline
{
    XMPPPresence *presence = [XMPPPresence presence];
    debugLog(@"goOnline: %@", presence);
    [self.xmppStream sendElement:presence];
}

- (void)goOffline
{
    XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
    debugLog(@"goOffline: %@", presence);
    [self.xmppStream sendElement:presence];
}

- (BOOL)connect
{
    [self setupStream];

    // If already connected, return true
    if ([self isConnected]) {
        return YES;
    }

    // If invalid credentials, return false
    NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:CACHE_KEY_LOGIN_USERNAME];
    NSString *password = [[NSUserDefaults standardUserDefaults] objectForKey:CACHE_KEY_LOGIN_PASSWORD];
    if (username == nil || password == nil) {
        return NO;
    }

    // Set username and try to connect
    [self.xmppStream setMyJID:[XMPPJID jidWithString:username]];
    NSError *error = nil;
    if (![self.xmppStream connectWithTimeout:TIME_CONNECTION_TIMEOUT error:&error])
    {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"POPUP_ERROR_TITLE", nil)
            message:NSLocalizedString(@"ERROR_CONNECT", nil)
            delegate:nil
            cancelButtonTitle:NSLocalizedString(@"POPUP_CONFIRM_BUTTON_TITLE", nil)
            otherButtonTitles:nil] show];
        NSLog(@"ERROR: %@", [error localizedDescription]);
        return NO;
    }
    return YES;
}

- (void)disconnect
{
    [self goOffline];
    [self.xmppStream disconnect];
}

/** @brief Returns whether or not xmpp is connected */
- (BOOL)isConnected
{
    // If stream is not disconnected, it is either establishing connection or connected
    return ![self.xmppStream isDisconnected];
}


#pragma mark - XMPPStreamDelegate

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    debugLog(@"xmppStreamDidConnect: %@", sender);

    NSError *error = nil;
    NSString *password = [[NSUserDefaults standardUserDefaults] objectForKey:CACHE_KEY_LOGIN_PASSWORD];
    if (![[self xmppStream] authenticateWithPassword:password error:&error]) {
        debugLog(@"ERROR: Could not authenticate! %@", error);
    }
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender {
    [self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    debugLog(@"Presence Update: %@", presence);

    NSString *user = [[presence from] user];
    if (![user isEqualToString:[[sender myJID] user]])
    {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:NOTIFICATION_PRESENCE_UPDATE
            object:self userInfo:@{
                @"presence":[presence type],
                @"username":[NSString stringWithFormat:@"%@@%@", user, GCHAT_DOMAIN],
            }];
    }
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    debugLog(@"Message Update: %@", message);

    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_MESSAGE_RECEIVED
        object:self userInfo:@{
            @"message": [[message elementForName:@"body"] stringValue],
            @"sender": [[message attributeForName:@"from"] stringValue],
            @"timestamp": [NSDate date],
        }];
}


@end
