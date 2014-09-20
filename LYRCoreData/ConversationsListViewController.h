//
//  ConversationsListViewController.h
//  LYRCoreData
//
//  Created by Blake Watters on 9/20/14.
//  Copyright (c) 2014 Layer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>
#import <LayerKit/LayerKit.h>

@interface ConversationsListViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (nonatomic) LYRClient *layerClient;
@property (nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic) NSManagedObjectContext *managedObjectContext;

@end
