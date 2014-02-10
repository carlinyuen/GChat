/**
	@file	AppDelegate.h
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.

#import <UIKit/UIKit.h>

#import "XMPPFramework.h"
#import "Reachability.h"

@class AppViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

	@property (strong, nonatomic) UIWindow *window;

	@property (strong, nonatomic) AppViewController *viewController;
   
    /** To check on rechability */
    @property (strong, nonatomic) Reachability *reachability;

    /** XMPP stuff */
    @property (strong, nonatomic, readonly) XMPPStream *xmppStream;
    @property (strong, nonatomic) XMPPRoster *roster;
    @property (strong, nonatomic) XMPPRosterMemoryStorage *rosterStorage;
    @property (strong, nonatomic) XMPPMessageArchiving *messageArchive;
    @property (strong, nonatomic) XMPPMessageArchivingCoreDataStorage *messageArchiveStorage;
    @property (strong, nonatomic) XMPPvCardCoreDataStorage *avatarStorage;
    @property (strong, nonatomic) XMPPvCardTempModule *avatarTemp;
    @property (strong, nonatomic) XMPPvCardAvatarModule *avatarCards;

    /** @brief Returns a reference to app delegate */
    + (AppDelegate *)appDelegate;

    /** @brief Clears saved credentials */
    + (void)clearCredentials;

    /** @brief Attempt login to xmpp service */
    - (BOOL)connectWithUsername:(NSString *)username andPassword:(NSString *)password;

    /** @brief Disconnect from xmpp service */
    - (void)disconnect;

    /** @brief Returns whether or not xmpp is connected */
    - (BOOL)isConnected;

@end
