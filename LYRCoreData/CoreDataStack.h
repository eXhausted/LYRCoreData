//
//  CoreDataStack.h
//  LYRCoreData
//
//  Created by Blake Watters on 9/20/14.
//  Copyright (c) 2014 Layer. All rights reserved.
//

#import <CoreData/CoreData.h>

/**
 @abstract The `CoreDataStack` class encapsulates the configuration of a complete Core Data stack. It utilizes a pair of managed object contexts: one dedicated to persistence and another to servicing the user interface on the main thread.
 */
@interface CoreDataStack : NSObject

///-------------------------------------
/// @name Initializing a Core Data Stack
///-------------------------------------

/**
 @abstract Creates and returns a new Core Data stack initialized with the given managed object model.
 
 @param model The managed object model with which to initialize the Core Data stack.
 @returns A newly initialized Core Data stack that is ready for configuration.
 @raises NSInvalidArgumentException Raised if `model` is nil.
 */
+ (instancetype)stackWithManagedObjectModel:(NSManagedObjectModel *)model;

/**
 @abstract Initializes the receiver with the given persistent store coordinator.
 
 @discussion This is the designated initializer.
 
 @param persistentStoreCoordinator The persistent store coordinator with which to initialize the receiver.
 @returns The receiver, initialized with the given persistent store coordinator.
 @raises NSInvalidArgumentException Raised if `persistentStoreCoordinator` is nil.
 */
- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator;

/**
 @abstract The persistent coordinator of the receiver.
 */
@property (nonatomic, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

///-------------------------------------------
/// @name Working with Managed Object Contexts
///-------------------------------------------

/**
 @abstract Creates the persistence and user interface contexts for the receiver once persistent store configuration is complete.
 
 @see `persistenceContext`
 @see `userInterfaceContext`
 @raises NSInternalInconsistencyException Raised if the managed object contexts have already been created.
 */
- (void)createManagedObjectContexts;

/**
 @abstract Returns the managed object context of the receiver that is associated with the persistent store coordinator and is responsible for managing persistence.
 
 @discussion The persistentence context is created with the `NSPrivateQueueConcurrencyType` and as such must be interacted with using `[NSManagedObjectContext performBlock:]` or `[NSManagedObjectContext performBlockAndWait:]`. This context serves as the parent context for scratch contexts or main queue contexts for interacting with the user interface. Created by the invocation of `createManagedObjectContexts`.
 
 @see `createManagedObjectContexts`
 */
@property (nonatomic, readonly) NSManagedObjectContext *persistenceContext;

/**
 @abstract Returns the managed object context of the receiver that is dedicated to servicing the user interface.
 
 @discussion The context is created with the NSMainQueueConcurrencyType and as such may be messaged directly from the main thread. The context is a child context of the persistence context and can persist changes up to the parent via a save.
 */
@property (nonatomic, readonly) NSManagedObjectContext *userInterfaceContext;

/**
 @abstract Saves the receiver's managed object contexts back to the persistent store.
 
 @discussion This method will save the `userInterfaceContext` if there are any changes to 'push' the changes back into the `persistenceContext`, which is then also saved.
 
 @param error A pointer to an error object that is set in the event that the save is unsuccessful.
 @returns A Boolean value that indicates if the save operation was successful.
 */
- (BOOL)saveContexts:(NSError **)error;

@end
