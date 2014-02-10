/**
	@file	AppDelegate.m
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.

#import "AppDelegate.h"

#import "AppViewController.h"
#import "GCContactsViewController.h"
#import "GCLoginViewController.h"

    #define TIME_CONNECTION_TIMEOUT 8  // In seconds

    // Defined here https://developers.google.com/talk/open_communications
    #define GCHAT_DOMAIN @"talk.google.com"
    #define GCHAT_PORT 5222

@interface AppDelegate() <
    XMPPStreamDelegate
>

    /** XMPP stuff */
    @property (strong, nonatomic, readwrite) XMPPStream *xmppStream;
    @property (strong, nonatomic) XMPPReconnect *xmppReconnect;

    /** Temporary password storage for login */
    @property (copy, nonatomic) NSString *tempPassword;

    /** To extend time we can receive local notifications */
    @property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTask;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Setup reachability
    self.reachability = [Reachability reachabilityWithHostname:GCHAT_DOMAIN];
    [self.reachability startNotifier];

    // Create base view controller
    self.viewController = [[AppViewController alloc] initWithNibName:@"AppViewController" bundle:nil];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self.viewController];
	self.window.rootViewController = nav;

    // Handle notifications
    UILocalNotification *notification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (notification)
    {
        debugLog(@"launchedWithLocalNotification: %@", notification.userInfo);
        [self application:application didReceiveLocalNotification:notification];
    }

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
    // Perform cleanup
    [self cleanup];

    // Kick off background task
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler: ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [application endBackgroundTask:self.backgroundTask];
            self.backgroundTask = UIBackgroundTaskInvalid;
        });
    }];

    // Find out how much time we have
    debugLog(@"Background time left: %@", @([[UIApplication sharedApplication] backgroundTimeRemaining]));
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
    [self.viewController viewDidAppear:true];
}

/** @brief Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
*/
- (void)applicationWillTerminate:(UIApplication *)application
{
    [self disconnect];

    // Perform cleanup
    [self cleanup];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    debugLog(@"receivedLocalNotification: %@", notification.userInfo);

    // Jump to chat screen if is a chat
//    if ([notification.userInfo[XMPP_MESSAGE_TYPE] isEqualToString:XMPP_MESSAGE_TYPE_CHAT] && [[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
//    {
//        UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
//        [nav popToRootViewControllerAnimated:false];
//        [self.viewController selectContact:notification.userInfo[XMPP_MESSAGE_USERNAME]];
//    }
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
}

/** @brief Perform app cleanup */
- (void)cleanup
{
    debugLog(@"cleanup");

    // Disable timers
//    [self.viewController cancelPollingTimer];

    // Clear credentials
    if (![[NSUserDefaults standardUserDefaults] boolForKey:CACHE_KEY_LOGIN_PERSIST]) {
        [AppDelegate clearCredentials];
    }
}

/** @brief Returns a reference to app delegate */
+ (AppDelegate *)appDelegate
{
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

/** @brief Clears saved credentials */
+ (void)clearCredentials
{
    debugLog(@"clearCredentials");

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:CACHE_KEY_LOGIN_PASSWORD];
    [defaults synchronize];
}


#pragma mark - XMPP Setup

- (void)setupStream
{
    if (!self.xmppStream)
    {
        self.xmppStream = [XMPPStream new];
//        [self.xmppStream setHostName:GCHAT_DOMAIN];
//        [self.xmppStream setHostPort:GCHAT_PORT];
        [self.xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];

        // Modules
        // Reconnect Automatically
        self.xmppReconnect = [XMPPReconnect new];
        [self.xmppReconnect activate:self.xmppStream];

        // Roster Setup
        self.rosterStorage = [XMPPRosterMemoryStorage new];
        self.roster = [[XMPPRoster alloc] initWithRosterStorage:self.rosterStorage];
        [self.roster activate:[[AppDelegate appDelegate] xmppStream]];

        // Message archive
        self.messageArchiveStorage = [XMPPMessageArchivingCoreDataStorage sharedInstance];
        self.messageArchive = [[XMPPMessageArchiving alloc] initWithMessageArchivingStorage:self.messageArchiveStorage];
        [self.messageArchive activate:self.xmppStream];

        // vCard
        self.avatarStorage = [XMPPvCardCoreDataStorage sharedInstance];
        self.avatarTemp = [[XMPPvCardTempModule alloc] initWithvCardStorage:self.avatarStorage];
        self.avatarCards = [[XMPPvCardAvatarModule alloc] initWithvCardTempModule:self.avatarTemp];
        [self.avatarCards activate:[[AppDelegate appDelegate] xmppStream]];
    }
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

- (BOOL)connectWithUsername:(NSString *)username andPassword:(NSString *)password
{
    debugLog(@"connect xmpp");

    [self setupStream];

    // If already connected, return true
    if ([self isConnected]) {
        debugLog(@"Already connected!");
        return YES;
    }

    // Get username to use for authentication
    if (!username) {
        username = [[NSUserDefaults standardUserDefaults] objectForKey:CACHE_KEY_LOGIN_USERNAME];
    }
    self.tempPassword = (password ? password    // Store in temp variable
        : [[NSUserDefaults standardUserDefaults] objectForKey:CACHE_KEY_LOGIN_PASSWORD]);

    // If invalid credentials, return false
    if (!username || !self.tempPassword) {
        return NO;
    }
    
    // Notify connection status change
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            XMPP_STATUS: XMPP_CONNECTION_CONNECTING,
            XMPP_TIMESTAMP: [NSDate date],
        }];

    // Set username and try to connect
    [self.xmppStream setMyJID:[XMPPJID jidWithString:username]];
    NSError *error;
    if (![self.xmppStream connectWithTimeout:TIME_CONNECTION_TIMEOUT error:&error])
    {
        debugLog(@"connect failed@");
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
    debugLog(@"isConnected: %i", ![self.xmppStream isDisconnected]);

    // If stream is not disconnected, it is either establishing connection or connected
    return ![self.xmppStream isDisconnected];
}


#pragma mark - XMPPStreamDelegate

- (void)xmppStream:(XMPPStream *)sender didNotRegister:(NSXMLElement *)error
{
    debugLog(@"XMPP REGISTER ERROR: %@", error);
    
    // Notify connection status change
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            XMPP_STATUS: XMPP_CONNECTION_ERROR_REGISTER,
            XMPP_TIMESTAMP: [NSDate date],
        }];
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    debugLog(@"xmppStreamDidConnect: %@", sender);

    // Notify connection status change
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            XMPP_STATUS: XMPP_CONNECTION_AUTH,
            XMPP_TIMESTAMP: [NSDate date],
        }];

    // Try to authenticate
    NSError *error = nil;
    if (![[self xmppStream] authenticateWithPassword:self.tempPassword error:&error])
    {
        debugLog(@"ERROR: Could not authenticate! %@", error);

        // Clear temp password
        self.tempPassword = nil;

        // Notify connection status change
        [[NSNotificationCenter defaultCenter]
            postNotificationName:NOTIFICATION_CONNECTION_CHANGED
            object:self userInfo:@{
                XMPP_STATUS: XMPP_CONNECTION_ERROR_AUTH,
                XMPP_TIMESTAMP: [NSDate date],
            }];

        [[self xmppStream] disconnect];
    }
}

- (void)xmppStreamConnectDidTimeout:(XMPPStream *)sender
{
    debugLog(@"xmpp timeout");

    // Notify connection status change
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            XMPP_STATUS: XMPP_CONNECTION_ERROR_TIMEOUT,
            XMPP_TIMESTAMP: [NSDate date],
        }];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    // Clear temp password
    self.tempPassword = nil;

    // Authenticated, notify
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            XMPP_STATUS: XMPP_CONNECTION_OK,
            XMPP_TIMESTAMP: [NSDate date],
        }];

    // Update status
    [self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
    debugLog(@"XMPP AUTHENTICATE ERROR: %@", error);

    // Clear temp password
    self.tempPassword = nil;

    // Notify connection status change
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            XMPP_STATUS: XMPP_CONNECTION_ERROR_AUTH,
            XMPP_TIMESTAMP: [NSDate date],
        }];

    [[self xmppStream] disconnect];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(NSXMLElement *)error
{
    debugLog(@"XMPP ERROR: %@", error);
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    NSString *user = [[presence from] bare];
    if (![user isEqualToString:[[sender myJID] bare]])
    {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:NOTIFICATION_PRESENCE_UPDATE
            object:self userInfo:@{
                XMPP_PRESENCE_TYPE: [presence type],
                XMPP_PRESENCE_SHOW: ([presence show] ? [presence show] : XMPP_PRESENCE_SHOW_CHAT),  // null == ready to chat
                XMPP_PRESENCE_STATUS: ([presence status] ? [presence status] : @""),
                XMPP_PRESENCE_USERNAME: user,
                XMPP_TIMESTAMP: [NSDate date],
            }];
    }
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
    debugLog(@"message: %@", message);

    // Only register if has message body and is a chat message
    if ([message body] && [[message type] isEqualToString:XMPP_MESSAGE_TYPE_CHAT])
    {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:NOTIFICATION_MESSAGE_RECEIVED
            object:self userInfo:@{
                XMPP_MESSAGE_TEXT: [message body],
                XMPP_MESSAGE_USERNAME: [[message from] bare],
                XMPP_MESSAGE_TYPE: [message type],
                XMPP_TIMESTAMP: [NSDate date],
            }];
    }
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
    // Allow self-signed certificates
    [settings setObject:@YES forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];

    // Allow host name mismatches
    [settings setObject:[NSNull null] forKey:(NSString *)kCFStreamSSLPeerName];
}


@end
