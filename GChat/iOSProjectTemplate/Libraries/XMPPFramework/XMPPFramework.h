//
//  This file is designed to be customized by YOU.
//  
//  Copy this file and rename it to "XMPPFramework.h". Then add it to your project.
//  As you pick and choose which parts of the framework you need for your application, add them to this header file.
//  
//  Various modules available within the framework optionally interact with each other.
//  E.g. The XMPPPing module utilizes the XMPPCapabilities module to advertise support XEP-0199.
// 
//  However, the modules can only interact if they're both added to your xcode project.
//  E.g. If XMPPCapabilities isn't a part of your xcode project, then XMPPPing shouldn't attempt to reference it.
// 
//  So how do the individual modules know if other modules are available?
//  Via this header file.
// 
//  If you #import "XMPPCapabilities.h" in this file, then _XMPP_CAPABILITIES_H will be defined for other modules.
//  And they can automatically take advantage of it.
//

//  CUSTOMIZE ME !
//  THIS HEADER FILE SHOULD BE TAILORED TO MATCH YOUR APPLICATION.

//  The following is standard:

#import "XMPP.h"

    #define XMPP_TIMESTAMP @"timestamp"
    #define XMPP_STATUS @"status"

    #define XMPP_MESSAGE_TO @"to"
    #define XMPP_MESSAGE_FROM @"from"
    #define XMPP_MESSAGE_TEXT @"text"
    #define XMPP_MESSAGE_USERNAME @"user"
    #define XMPP_MESSAGE_TYPE @"type"
    #define XMPP_MESSAGE_TYPE_CHAT @"chat"
    #define XMPP_MESSAGE_TYPE_ERROR @"error"

    #define XMPP_CONNECTION_OK @"ok"
    #define XMPP_CONNECTION_CONNECTING @"connect"
    #define XMPP_CONNECTION_AUTH @"auth"
    #define XMPP_CONNECTION_ERROR_AUTH @"unauth"
    #define XMPP_CONNECTION_ERROR_TIMEOUT @"timeout"
    #define XMPP_CONNECTION_ERROR_REGISTER @"unregistered"
    #define XMPP_CONNECTION_ERROR @"error"

    #define XMPP_PRESENCE_TYPE @"type"
    #define XMPP_PRESENCE_TYPE_OFFLINE @"unavailable"
    #define XMPP_PRESENCE_TYPE_ONLINE @"available"
    #define XMPP_PRESENCE_TYPE_ERROR @"error"
    #define XMPP_PRESENCE_TYPE_UNSUB @"unsubscribe"
    #define XMPP_PRESENCE_TYPE_UNSUBBED @"unsubscribed"
    #define XMPP_PRESENCE_TYPE_SUB @"subscribe"
    #define XMPP_PRESENCE_TYPE_SUBBED @"subscribed"
    #define XMPP_PRESENCE_TYPE_PROBE @"probe"

    #define XMPP_PRESENCE_STATUS @"status"
    #define XMPP_PRESENCE_USERNAME @"username"
    #define XMPP_PRESENCE_DOMAIN @"domain"

    #define XMPP_PRESENCE_SHOW @"show"
    #define XMPP_PRESENCE_SHOW_AWAY @"away"
    #define XMPP_PRESENCE_SHOW_AWAY_EXTENDED @"xa"
    #define XMPP_PRESENCE_SHOW_BUSY @"dnd"
    #define XMPP_PRESENCE_SHOW_CHAT @"chat"
 
// List the modules you're using here:

//#import "XMPPBandwidthMonitor.h"
 
#import "XMPPCoreDataStorage.h"

#import "XMPPReconnect.h"

#import "XMPPRoster.h"
#import "XMPPRosterMemoryStorage.h"
//#import "XMPPRosterCoreDataStorage.h"

#import "XMPPGoogleSharedStatus.h"

//#import "XMPPJabberRPCModule.h"
//#import "XMPPIQ+JabberRPC.h"
//#import "XMPPIQ+JabberRPCResponse.h"
//
//#import "XMPPPrivacy.h"

#import "XMPPMUC.h"
#import "XMPPRoom.h"
#import "XMPPRoomMemoryStorage.h"
//#import "XMPPRoomCoreDataStorage.h"
//#import "XMPPRoomHybridStorage.h"

#import "XMPPvCardTempModule.h"
#import "XMPPvCardCoreDataStorage.h"

//#import "XMPPPubSub.h"
//
//#import "TURNSocket.h"
//
#import "XMPPDateTimeProfiles.h"
#import "NSDate+XMPPDateTimeProfiles.h"

#import "XMPPMessage+XEP_0085.h"
#import "XMPPMessageArchiving.h"
#import "XMPPMessageArchivingCoreDataStorage.h"

//#import "XMPPTransports.h"

#import "XMPPCapabilities.h"
#import "XMPPCapabilitiesCoreDataStorage.h"

#import "XMPPvCardAvatarModule.h"

//#import "XMPPMessage+XEP_0184.h"
//
//#import "XMPPPing.h"
//#import "XMPPAutoPing.h"
//
//#import "XMPPTime.h"
//#import "XMPPAutoTime.h"
//
//#import "XMPPElement+Delay.h"
