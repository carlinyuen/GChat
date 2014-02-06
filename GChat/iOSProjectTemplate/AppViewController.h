/**
	@file	AppViewController.h
	@author	Carlin
	@date	7/12/13
	@brief	iOSProjectTemplate
*/
//  Copyright (c) 2013 Carlin. All rights reserved.


#import <UIKit/UIKit.h>

#import "GCContactsViewController.h"

@interface AppViewController : UIViewController

    @property (strong, nonatomic) GCContactsViewController *contactsVC;

@end
