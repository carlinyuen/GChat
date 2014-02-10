/**
	@file	Constants.m
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.

#import "Constants.h"

// UI
float const SIZE_MIN_TOUCH = 44;

// Cached Data
NSString* const CACHE_KEY_USER_SETTINGS = @"cacheUserSettings";
NSString* const CACHE_KEY_LOGIN_USERNAME = @"loginUsername";
NSString* const CACHE_KEY_LOGIN_PASSWORD = @"loginPassword";
NSString* const CACHE_KEY_LOGIN_PERSIST = @"loginPersist";
NSString* const CACHE_KEY_CONTACTS_SORT_TYPE = @"contactsSortType";

// One-time flags
NSString* const ONCE_KEY_APP_OPENED = @"onceAppOpened";

// Notifications
NSString* const NOTIFICATION_PRESENCE_UPDATE = @"notificationStatusUpdate";
NSString* const NOTIFICATION_MESSAGE_RECEIVED = @"notificationMessageReceived";
NSString* const NOTIFICATION_CONNECTION_CHANGED = @"notificationConnectionChanged";

// Fonts
NSString* const FONT_NAME_BRANDING = @"Courier New";
NSString* const FONT_NAME_MEDIUM = @"HelveticaNeue-Medium";
NSString* const FONT_NAME_THIN = @"HelveticaNeue-Thin";
NSString* const FONT_NAME_LIGHT = @"HelveticaNeue-Light";
NSString* const FONT_NAME_THINNEST = @"HelveticaNeue-UltraLight";
float const FONT_SIZE_TITLE = 33;
float const FONT_SIZE_NAVBAR = 20;
float const FONT_SIZE_BRANDING = 22;
float const FONT_SIZE_CHAT_INPUT = 14;
float const FONT_SIZE_CONTACT_NAME = 22;
float const FONT_SIZE_CONTACT_STATUS = 14;
float const FONT_SIZE_CROUTON = 14;

// Time
int const TIME_ONE_MINUTE = 60;
int const TIME_ONE_HOUR = 3600;
int const TIME_ONE_DAY = 86400;
int const MICROSECONDS_PER_SECOND = 1000000;

// Colors
int const COLOR_HEX_BACKGROUND_DARK = 0x222222FF;
int const COLOR_HEX_BACKGROUND_LIGHT = 0xF8F8F8FF;
int const COLOR_HEX_COPY_DARK = 0x464646FF;
int const COLOR_HEX_COPY_LIGHT = 0x7D7D7DFF;
int const COLOR_HEX_APPLE_BUTTON_BLUE = 0x007AFFFF;
int const COLOR_HEX_APPLE_BUTTON_BLUE_SELECTED = 0x004ACFCF;
int const COLOR_HEX_SHOW_ONLINE = 0xA3FFABFF;
int const COLOR_HEX_SHOW_ONLINE_SELECTED = 0x55E661FF;
int const COLOR_HEX_SHOW_BUSY = 0xFFB1B0FF;
int const COLOR_HEX_SHOW_BUSY_SELECTED = 0xEB524BFF;
int const COLOR_HEX_SHOW_AWAY = 0xFFDBA3FF;
int const COLOR_HEX_SHOW_AWAY_SELECTED = 0xFFBB52FF;
int const COLOR_HEX_SHOW_OFFLINE = 0xFFFFFFFF;
int const COLOR_HEX_BLACK_TRANSPARENT = 0x00000088;
int const COLOR_HEX_WHITE_TRANSPARENT = 0xFFFFFF88;
int const COLOR_HEX_WHITE_TRANSLUCENT = 0xFFFFFFBB;
int const COLOR_HEX_GREY_TRANSPARENT = 0x88888888;

// Animations
float const ANIMATION_DURATION_FAST = 0.3;
float const ANIMATION_DURATION_MED = 0.5;
float const ANIMATION_DURATION_SLOW = 0.7;

// Regex
NSString* const REGEX_EMAIL_VERIFICATION =
    @"(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
    @"~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
    @"x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
    @"z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
    @"]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
    @"9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
    @"-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])";

