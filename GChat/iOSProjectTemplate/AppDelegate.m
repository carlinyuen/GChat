/**
	@file	AppDelegate.m
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.

#import "AppDelegate.h"

#import "AppViewController.h"

    #define TIME_CONNECTION_TIMEOUT 6  // In seconds

    // Defined here https://developers.google.com/talk/open_communications
    #define GCHAT_DOMAIN @"talk.google.com"
    #define GCHAT_PORT 5222

@interface AppDelegate() <
    XMPPStreamDelegate
>

    @property (strong, nonatomic, readwrite) XMPPStream *xmppStream;
    @property (strong, nonatomic) XMPPReconnect *xmppReconnect;

    @property (strong, nonatomic) NSTimer *connectTimeoutTimer;

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
    // Perform cleanup
    [AppDelegate cleanup];
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
    [self connectWithUsername:nil andPassword:nil];
}

/** @brief Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
*/
- (void)applicationWillTerminate:(UIApplication *)application
{
    // Perform cleanup
    [AppDelegate cleanup];
}

/** @brief Returns a reference to app delegate */
+ (AppDelegate *)appDelegate
{
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

/** @brief Perform app cleanup */
+ (void)cleanup
{
    debugLog(@"cleanup");

    if (![[NSUserDefaults standardUserDefaults] boolForKey:CACHE_KEY_LOGIN_PERSIST]) {
        [AppDelegate clearCredentials];
    }
}

/** @brief Clears saved credentials */
+ (void)clearCredentials
{
    debugLog(@"clearCredentials");

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:CACHE_KEY_LOGIN_USERNAME];
    [defaults removeObjectForKey:CACHE_KEY_LOGIN_PASSWORD];
    [defaults removeObjectForKey:CACHE_KEY_LOGIN_PERSIST];
    [defaults synchronize];
}


#pragma mark - XMPP Setup

- (void)setupStream
{
    if (!self.xmppStream)
    {
        self.xmppStream = [XMPPStream new];
        [self.xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];

        // Modules
        self.xmppReconnect = [XMPPReconnect new];
        [self.xmppReconnect activate:self.xmppStream];
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

    // If invalid credentials, return false
    if (!username) {
        username = [[NSUserDefaults standardUserDefaults] objectForKey:CACHE_KEY_LOGIN_USERNAME];
    }
    if (!password) {
        password = [[NSUserDefaults standardUserDefaults] objectForKey:CACHE_KEY_LOGIN_PASSWORD];
    }
    debugLog(@"Credentials: %@ / %@", username, password);
    if (!username || !password) {
        return NO;
    }
    
    // Notify connection status change
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            @"status": @"connecting",
            @"timestamp": [NSDate date],
        }];

    // Set username and try to connect
    [self.xmppStream setMyJID:[XMPPJID jidWithString:username]];
    NSError *error = nil;
    if (self.connectTimeoutTimer) {
        [self.connectTimeoutTimer invalidate];
    }
    self.connectTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:TIME_CONNECTION_TIMEOUT
        target:self selector:@selector(xmppStreamConnectDidTimeout:)
        userInfo:nil repeats:false];
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
            @"status": @"timeout",
            @"timestamp": [NSDate date],
        }];
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    debugLog(@"xmppStreamDidConnect: %@", sender);

    // Invalidate timeout timer
    if (self.connectTimeoutTimer) {
        [self.connectTimeoutTimer invalidate];
    }

    // Notify connection status change
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            @"status": @"authenticating",
            @"timestamp": [NSDate date],
        }];

    // Try to authenticate
    NSError *error = nil;
    NSString *password = [[NSUserDefaults standardUserDefaults] objectForKey:CACHE_KEY_LOGIN_PASSWORD];
    if (![[self xmppStream] authenticateWithPassword:password error:&error]) {
        debugLog(@"ERROR: Could not authenticate! %@", error);
    }
}

- (void)xmppStreamConnectDidTimeout:(XMPPStream *)sender
{
    debugLog(@"xmpp timeout");

    // Notify connection status change
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            @"status": @"timeout",
            @"timestamp": [NSDate date],
        }];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    // Authenticated, notify
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            @"status": @"connected",
            @"timestamp": [NSDate date],
        }];

    // Update status
    [self goOnline];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
    debugLog(@"XMPP AUTHENTICATE ERROR: %@", error);

    // Notify connection status change
    [[NSNotificationCenter defaultCenter]
        postNotificationName:NOTIFICATION_CONNECTION_CHANGED
        object:self userInfo:@{
            @"status": @"timeout",
            @"timestamp": [NSDate date],
        }];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(NSXMLElement *)error
{
    debugLog(@"XMPP ERROR: %@", error);
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

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
    // Allow self-signed certificates
    [settings setObject:@YES forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];

    // Allow host name mismatches
    [settings setObject:[NSNull null] forKey:(NSString *)kCFStreamSSLPeerName];
}


@end
