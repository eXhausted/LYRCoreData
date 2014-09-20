//
//  DetailViewController.h
//  LYRCoreData
//
//  Created by Blake Watters on 9/20/14.
//  Copyright (c) 2014 Layer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <LayerKit/LayerKit.h>
#import <CoreData/CoreData.h>

@interface ConversationViewController : UITableViewController

@property (nonatomic) LYRClient *layerClient;
@property (nonatomic) NSManagedObject *conversation;

@end
