/**
	@file	Constants.h
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.

#import <Foundation/Foundation.h>

// UI
extern float const SIZE_MIN_TOUCH;

// Cached Data
extern NSString* const CACHE_KEY_USER_SETTINGS;
extern NSString* const CACHE_KEY_LOGIN_USERNAME;
extern NSString* const CACHE_KEY_LOGIN_PASSWORD;
extern NSString* const CACHE_KEY_LOGIN_PERSIST;
extern NSString* const CACHE_KEY_CONTACTS_SORT_TYPE;

// One-time flags
extern NSString* const ONCE_KEY_APP_OPENED;

// Notifications
extern NSString* const NOTIFICATION_PRESENCE_UPDATE;
extern NSString* const NOTIFICATION_MESSAGE_RECEIVED;
extern NSString* const NOTIFICATION_CONNECTION_CHANGED;

// Fonts
extern NSString* const FONT_NAME_BRANDING;
extern NSString* const FONT_NAME_MEDIUM;
extern NSString* const FONT_NAME_THIN;
extern NSString* const FONT_NAME_LIGHT;
extern NSString* const FONT_NAME_THINNEST;
extern float const FONT_SIZE_TITLE;
extern float const FONT_SIZE_NAVBAR;
extern float const FONT_SIZE_BRANDING;
extern float const FONT_SIZE_CHAT_INPUT;
extern float const FONT_SIZE_CONTACT_NAME;
extern float const FONT_SIZE_CONTACT_STATUS;
extern float const FONT_SIZE_CROUTON;

// Time
extern int const TIME_ONE_MINUTE;
extern int const TIME_ONE_HOUR;
extern int const TIME_ONE_DAY;
extern int const MICROSECONDS_PER_SECOND;

// Colors
extern int const COLOR_HEX_BACKGROUND_DARK;
extern int const COLOR_HEX_BACKGROUND_LIGHT;
extern int const COLOR_HEX_COPY_DARK;
extern int const COLOR_HEX_COPY_LIGHT;
extern int const COLOR_HEX_APPLE_BUTTON_BLUE;
extern int const COLOR_HEX_APPLE_BUTTON_BLUE_SELECTED;
extern int const COLOR_HEX_SHOW_AWAY;
extern int const COLOR_HEX_SHOW_AWAY_SELECTED;
extern int const COLOR_HEX_SHOW_ONLINE;
extern int const COLOR_HEX_SHOW_ONLINE_SELECTED;
extern int const COLOR_HEX_SHOW_BUSY;
extern int const COLOR_HEX_SHOW_BUSY_SELECTED;
extern int const COLOR_HEX_SHOW_OFFLINE;
extern int const COLOR_HEX_BLACK_TRANSPARENT;
extern int const COLOR_HEX_WHITE_TRANSPARENT;
extern int const COLOR_HEX_WHITE_TRANSLUCENT;
extern int const COLOR_HEX_GREY_TRANSPARENT;

// Animations
extern float const ANIMATION_DURATION_FAST;
extern float const ANIMATION_DURATION_MED;
extern float const ANIMATION_DURATION_SLOW;

// Regex
extern NSString* const REGEX_EMAIL_VERIFICATION;