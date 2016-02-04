
//
//  WKCoreDataStack.m
//  Wayke
//
//  Created by Bogdan Geleta on 11/5/15.
//  Copyright © 2015 Softheme. All rights reserved.
//

#import "WKCoreDataStack.h"

@interface WKCoreDataStack()

@property (nonatomic, strong) NSManagedObjectContext *mainContext;
@property (nonatomic, strong) NSManagedObjectContext *backgroundContext;

@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSManagedObjectModel *model;

@end

@implementation WKCoreDataStack

+ (instancetype)sharedStack {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)setupStack {
    self.mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.mainContext.persistentStoreCoordinator = self.coordinator;
    self.mainContext.undoManager = [[NSUndoManager alloc] init];
    
    self.backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    self.backgroundContext.persistentStoreCoordinator = self.coordinator;
    
    __weak WKCoreDataStack *weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification* notification) {
                                                      if (notification.object == weakSelf.backgroundContext) {
                                                          NSManagedObjectContext *moc = weakSelf.mainContext;
                                                          //[weakSelf printDebug:notification];
                                                          LYRLog(@"Will merge to MainContext");
                                                          [moc performBlock:^() {
                                                              [moc mergeChangesFromContextDidSaveNotification:notification];
                                                          }];
                                                      } else {
                                                          NSManagedObjectContext *moc = weakSelf.backgroundContext;
                                                          [moc performBlock:^() {
                                                              [moc mergeChangesFromContextDidSaveNotification:notification];
                                                          }];
                                                      }
     }];

}

- (void)printDebug:(NSNotification *)notifiaction {
    LYRLog(@"=========================================");
    [notifiaction.userInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, NSSet *  _Nonnull obj, BOOL * _Nonnull stop) {
        LYRLog(@"%@", key);
        [[obj allObjects] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            LYRLog(@"%@:%@", NSStringFromClass([obj class]), [obj identifier]);
        }];
    }];
    LYRLog(@"=========================================");
}

#pragma mark - Class methods

+ (void)saveWithBlockAndWait:(void (^)(NSManagedObjectContext *))block {
    [[self sharedStack] saveWithBlockAndWait:block];
}

+ (void)cleanUp {
    [self saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
    }];
}

#pragma mark -

- (void)saveWithBlockAndWait:(void (^)(NSManagedObjectContext *))block {
    if (block) {
        __weak WKCoreDataStack *weakSelf = self;
        [self.backgroundContext performBlockAndWait:^{
            block(weakSelf.backgroundContext);
            [weakSelf saveContext:weakSelf.backgroundContext];
        }];
    }
}

- (BOOL)saveContext:(NSManagedObjectContext *)context {
    NSError *error = nil;
    BOOL result = NO;
    
    if ([context hasChanges]) {
        result = [context save:&error];
        if (error) {
            LYRLog(@"Error: %@", error.localizedDescription);
        }
    }
    
    LYRLog(@"saveContext %d", result);
    return result;
}

#pragma mark -

+ (NSManagedObjectContext *)backgroundContext {
    return [[self sharedStack] backgroundContext];
}

+ (NSManagedObjectContext *)mainContext {
    return [[self sharedStack] mainContext];
}

#pragma mark -

- (NSPersistentStoreCoordinator *)coordinator {
    if (!_coordinator) {
        NSError *error = nil;
        _coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.model];
        id options = @{NSMigratePersistentStoresAutomaticallyOption: @(YES), NSInferMappingModelAutomaticallyOption: @(YES)};
        [_coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                   configuration:nil
                                             URL:[self storeURL]
                                         options:options
                                           error:&error];
        if (error) {
            LYRLog(@"CoreData error: %@", error);
        }
    }
    
    return _coordinator;
}

- (NSManagedObjectModel *)model {
    if (!_model) {
        NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"LYRCoreData" withExtension:@"momd"];
        _model  = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }
    
    return _model;
}

- (NSURL*)storeURL {
    NSURL* documentsDirectory = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory
                                                                       inDomain:NSUserDomainMask
                                                              appropriateForURL:nil
                                                                         create:YES
                                                                          error:NULL];
    
    return [documentsDirectory URLByAppendingPathComponent:@"LYRCoreData.sqlite"];
}

@end
