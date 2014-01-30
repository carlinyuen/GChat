//
//  GCChatViewController.h
//  GChat
//
//  Created by . Carlin on 1/30/14.
//  Copyright (c) 2014 Carlin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GCChatViewController : UIViewController

    /** Contact to initialize view for chat */
    @property (strong, nonatomic) NSDictionary *contactInfo;

    /** @brief Init with contact to chat with */
    - (id)initWithContact:(NSDictionary *)contact;

@end
