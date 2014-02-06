//
//  GCContactsViewController.h
//  GChat
//
//  Created by . Carlin on 2/6/14.
//  Copyright (c) 2014 Carlin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GCContactsViewController : UIViewController

    /** @brief Manually initiate pull to refresh */
    - (void)manualPullToRefresh;

    /** @brief Select and open up chat view for a specific contact */
    - (void)selectContact:(NSString *)username;
   
    /** @brief Start polling timer */
    - (void)startPollingTimer;

    /** @brief Cancel polling timer */
    - (void)cancelPollingTimer;
    
@end
