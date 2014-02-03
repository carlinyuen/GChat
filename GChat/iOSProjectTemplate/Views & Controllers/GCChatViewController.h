//
//  GCChatViewController.h
//  GChat
//
//  Created by . Carlin on 1/30/14.
//  Copyright (c) 2014 Carlin. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"

@interface GCChatViewController : UIViewController

    /** Contact to initialize view for chat */
    @property (strong, nonatomic) XMPPUserMemoryStorageObject *contact;

    /** @brief Init with contact to chat with */
    - (id)initWithContact:(XMPPUserMemoryStorageObject *)contact;

@end
