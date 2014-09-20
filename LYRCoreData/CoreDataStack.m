//
//  CoreDataManager.m
//  LYRCoreData
//
//  Created by Blake Watters on 9/20/14.
//  Copyright (c) 2014 Layer. All rights reserved.
//

#import "CoreDataStack.h"

@interface CoreDataStack ()
@property (nonatomic, readwrite) NSManagedObjectContext *persistenceContext;
@property (nonatomic, readwrite) NSManagedObjectContext *userInterfaceContext;
@end

@implementation CoreDataStack

+ (instancetype)stackWithManagedObjectModel:(NSManagedObjectModel *)model
{
    NSParameterAssert(model);
    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    return [[self alloc] initWithPersistentStoreCoordinator:persistentStoreCoordinator];
}

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    NSParameterAssert(persistentStoreCoordinator);
    self = [super init];
    if (self) {
        _persistentStoreCoordinator = persistentStoreCoordinator;
    }
    return self;
}

- (id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"Failed to call designated initializer: call `%@` instead.", NSStringFromSelector(@selector(initWithPersistentStoreCoordinator:))]
                                 userInfo:nil];
}

- (void)createManagedObjectContexts
{
    self.persistenceContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.persistenceContext.persistentStoreCoordinator = self.persistentStoreCoordinator;
    self.userInterfaceContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.userInterfaceContext.parentContext = self.persistenceContext;
}

- (BOOL)saveContexts:(NSError *__autoreleasing *)error
{
    if ([self.userInterfaceContext hasChanges]) {
        if (![self.userInterfaceContext save:error]) {
            return NO;
        } else {
            __block BOOL success;
            [self.persistenceContext performBlockAndWait:^{
                success = [self.persistenceContext save:error];
            }];
            return success;
        }
    } else if ([self.persistenceContext hasChanges]) {
        __block BOOL success;
        [self.persistenceContext performBlockAndWait:^{
            success = [self.persistenceContext save:error];
        }];
        return success;
    }
    
    return YES;
}

@end
