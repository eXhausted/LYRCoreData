//
//  LayerObjectChangeSynchronizer.h
//  LYRCoreData
//
//  Created by Blake Watters on 9/20/14.
//  Copyright (c) 2014 Layer. All rights reserved.
//

#import <LayerKit/LayerKit.h>
#import <CoreData/CoreData.h>

@protocol LayerObjectChangeSynchronizerDelegate;

/**
 @abstract The `LayerObjectChangeSynchronizer` class provides an interface for synchronizing a local Core Data model with a Layer client.
 @discussion The synchronizer works by maintaining private child managed object context and updating the object model in response to `LYRClientObjectsDidChangeNotification` notifications. Once each batch of changes is fully processed, the private context is saved, propoagating the changes back to its parent. For best performance, it is recommended that the context used to initialize the synchronizer does **NOT** have an ancestor context with a concurrency type of `NSMainQueueConcurrencyType`.
 */
@interface LayerObjectChangeSynchronizer : NSObject

//-----------------------------------
/// @name Initializing a Synchronizer
//-----------------------------------

/**
 @abstract Initializes the receiver with the given Layer client and target managed object model.
 @param layerClient The Layer client to be observed for object model changes.
 @param managedObjectContext The managed object context in which to synchronize the object model changes. This context is assumed to have a entities named `Conversation` and `Message` with attributes matching the `LYRConversation` and `LYRMessage` counterparts.
 */
- (id)initWithLayerClient:(LYRClient *)layerClient managedObjectContext:(NSManagedObjectContext *)managedObjectContext;

///-------------------------------------
/// @name Customizing Messaging Entities
///-------------------------------------

/**
 @abstract The Core Data entity used to model the local Conversation representation.
 @discussion Must have the attributes `createdAt` and `identifier` as well as the relationships `lastMessage` (one-to-one) and `messages` (one-to-many).
 */
@property (nonatomic) NSEntityDescription *conversationEntity;

/**
 @abstract The Core Data entity used to model the local Message representation.
 @discussion Must have the attributes `identifier`, `index`, `isSent`, `receivedAt`, `sentAt`, and `sentByUserID` as well as the relationships `conversation` (one-to-one) and `lastMessageConversation` (one-to-one).
 */
@property (nonatomic) NSEntityDescription *messageEntity;

///-----------------------------
/// @name Accessing the Delegate
///-----------------------------

/**
 @abstract The receiver's delegate.
 */
@property (nonatomic, weak) id<LayerObjectChangeSynchronizerDelegate> delegate;

///-------------------------------
/// @name Managing Synchronization
///-------------------------------

/**
 @abstract Suspends the processing of object change notifications, keeping the changes queued for later processing.
 @discussion Pausing the synchronizer can be useful during performance critical times.
 */
- (void)suspend;

/**
 @abstract Resumes the processing of object change notifications.
 */
- (void)resume;

/**
 @abstract Returns a Boolean value that indicates if the receiver has been suspended.
 */
@property (nonatomic, readonly) BOOL isSuspended;

@end

/**
 @abstract Objects wishing to act as the delegate for a `LayerObjectChangeSynchronizer` object must adopt the `LayerObjectChangeSynchronizerDelegate` protocol.
 */
@protocol LayerObjectChangeSynchronizerDelegate <NSObject>

@optional

/**
 @abstract Tells the delegate that the synchronizer has created a managed object for a Layer object.
 @param layerObjectChangeSynchronizer The Layer object change synchronizer.
 @param managedObject The managed object that was created.
 @param layerObject The Layer object that was synchronized into Core Data.
 */
- (void)layerObjectChangeSynchronizer:(LayerObjectChangeSynchronizer *)layerObjectChangeSynchronizer didCreateManagedObject:(NSManagedObject *)managedObject forLayerObject:(id)layerObject;

/**
 @abstract Tells the delegate that the synchronizer has update a managed object with a given property change for a Layer object.
 @param layerObjectChangeSynchronizer The Layer object change synchronizer.
 @param managedObject The managed object that was updated.
 @param layerObject The Layer object that was synchronized into Core Data.
 */
- (void)layerObjectChangeSynchronizer:(LayerObjectChangeSynchronizer *)layerObjectChangeSynchronizer didUpdateManagedObject:(NSManagedObject *)object withChange:(NSDictionary *)changes forLayerObject:(id)layerObject;

/**
 @abstract Tells the delegate that the synchronizer has deleted a managed object for a Layer object.
 @param layerObjectChangeSynchronizer The Layer object change synchronizer.
 @param managedObject The managed object that was deleted.
 @param layerObject The Layer object that was synchronized into Core Data.
 */
- (void)layerObjectChangeSynchronizer:(LayerObjectChangeSynchronizer *)layerObjectChangeSynchronizer didDeleteManagedObject:(NSManagedObject *)object forLayerObject:(id)layerObject;

@end
