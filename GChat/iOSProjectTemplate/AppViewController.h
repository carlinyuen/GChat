/**
	@file	AppViewController.h
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.


#import <UIKit/UIKit.h>

@interface AppViewController : UIViewController

    /** @brief Manually initiate pull to refresh */
    - (void)manualPullToRefresh;

    /** @brief Select and open up chat view for a specific contact */
    - (void)selectContact:(NSString *)username;
   
    /** @brief Start polling timer */
    - (void)startPollingTimer;

    /** @brief Cancel polling timer */
    - (void)cancelPollingTimer;

@end
