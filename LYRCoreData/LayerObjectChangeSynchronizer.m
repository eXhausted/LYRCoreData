//
//  LayerObjectChangeSynchronizer.m
//  LYRCoreData
//
//  Created by Blake Watters on 9/20/14.
//  Copyright (c) 2014 Layer. All rights reserved.
//

#import "LayerObjectChangeSynchronizer.h"

@interface LayerObjectIdentifierCache : NSObject

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;
- (NSManagedObject *)managedObjectWithEntity:(NSEntityDescription *)entity layerIdentifier:(NSURL *)layerObjectIdentifier;

@end

@interface LayerObjectChangeSynchronizer ()
@property (nonatomic) LYRClient *layerClient;
@property (nonatomic) NSOperationQueue *operationQueue;
@property (nonatomic) NSManagedObjectContext *synchronizerContext;
@property (nonatomic) LayerObjectIdentifierCache *objectCache;
@end

@implementation LayerObjectChangeSynchronizer

- (id)init
{
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:[NSString stringWithFormat:@"Failed to call designated initializer: call `%@` instead.",
                                           NSStringFromSelector(@selector(initWithLayerClient:managedObjectContext:))]
                                 userInfo:nil];
}

- (id)initWithLayerClient:(LYRClient *)layerClient managedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSParameterAssert(layerClient);
    NSParameterAssert(managedObjectContext);
    self = [super init];
    if (self) {
        _layerClient = layerClient;
        _operationQueue = [NSOperationQueue new];
        _operationQueue.maxConcurrentOperationCount = 1;
        _synchronizerContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _synchronizerContext.parentContext = managedObjectContext;
        _objectCache = [[LayerObjectIdentifierCache alloc] initWithManagedObjectContext:_synchronizerContext];
        _conversationEntity = [NSEntityDescription entityForName:@"Conversation" inManagedObjectContext:self.synchronizerContext];
        _messageEntity = [NSEntityDescription entityForName:@"Message" inManagedObjectContext:self.synchronizerContext];
        
        // Register for notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveLayerClientObjectsDidChangeNotification:) name:LYRClientObjectsDidChangeNotification object:layerClient];        
    }
    return self;
}

- (void)didReceiveLayerClientObjectsDidChangeNotification:(NSNotification *)notification
{
    [self.operationQueue addOperationWithBlock:^{
        [self.synchronizerContext performBlockAndWait:^{
            NSArray *changes = [notification.userInfo objectForKey:LYRClientObjectChangesUserInfoKey];
            for (NSDictionary *change in changes) {
                NSLog(@"Synchronizing %@", change);
                id changeObject = [change objectForKey:LYRObjectChangeObjectKey];
                LYRObjectChangeType updateKey = (LYRObjectChangeType)[[change objectForKey:LYRObjectChangeTypeKey] integerValue];
                switch (updateKey) {
                    case LYRObjectChangeTypeCreate: {
                        if ([changeObject isKindOfClass:[LYRConversation class]]) {
                            [self createConversation:changeObject];
                        } else if ([changeObject isKindOfClass:[LYRMessage class]]) {
                            [self createMessage:changeObject];
                        } else {
                            [NSException raise:NSInternalInconsistencyException format:@"Cannot synchronize object change: Unable to handle objects of type '%@' (change=%@)", [changeObject class], change];
                        }
                        break;
                    }
                    case LYRObjectChangeTypeUpdate: {
                        if ([changeObject isKindOfClass:[LYRConversation class]]) {
                            [self updateConversation:changeObject change:change];
                        } else if ([changeObject isKindOfClass:[LYRMessage class]]) {
                            [self updateMessage:changeObject change:change];
                        } else {
                            [NSException raise:NSInternalInconsistencyException format:@"Cannot synchronize object change: Unable to handle objects of type '%@' (change=%@)", [changeObject class], change];
                        }
                        break;
                    }
                    case LYRObjectChangeTypeDelete: {
                        if ([changeObject isKindOfClass:[LYRConversation class]]) {
                            [self deleteConversation:changeObject];
                        } else if ([changeObject isKindOfClass:[LYRMessage class]]) {
                            [self deleteMessage:changeObject];
                        } else {
                            [NSException raise:NSInternalInconsistencyException format:@"Cannot synchronize object change: Unable to handle objects of type '%@' (change=%@)", [changeObject class], change];
                        }
                        break;
                    }
                    default:
                        break;
                }
            }
            
            NSError *error = nil;
            BOOL success = [self.synchronizerContext save:&error];
            if (success) {
                success = [self.synchronizerContext.parentContext save:&error];
                if (success) {
                    
                } else {
                    
                }
                
                // TODO: Delegate...
            }
        }];
    }];
}

- (void)suspend
{
    self.operationQueue.suspended = YES;
}

- (void)resume
{
    self.operationQueue.suspended = NO;
}

- (BOOL)isSuspended
{
    return self.operationQueue.isSuspended;
}

#pragma mark - Private methods

- (void)createConversation:(LYRConversation *)conversation
{
    NSManagedObject *managedConversation = [[NSManagedObject alloc] initWithEntity:self.conversationEntity insertIntoManagedObjectContext:self.synchronizerContext];
    [self updateManagedConversation:managedConversation fromLayerConversation:conversation change:nil];
    
    if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didCreateManagedObject:forLayerObject:)]) {
        [self.delegate layerObjectChangeSynchronizer:self didCreateManagedObject:managedConversation forLayerObject:conversation];
    }
}

- (void)updateConversation:(LYRConversation *)conversation change:(NSDictionary *)change
{
    NSManagedObject *managedConversation = [self.objectCache managedObjectWithEntity:self.conversationEntity layerIdentifier:conversation.identifier];
    NSAssert(managedConversation, @"Conversation should not be nil.");
    [self updateManagedConversation:managedConversation fromLayerConversation:conversation change:change];
    
    if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didUpdateManagedObject:withChange:forLayerObject:)]) {
        [self.delegate layerObjectChangeSynchronizer:self didUpdateManagedObject:managedConversation withChange:change forLayerObject:conversation];
    }
}

- (void)deleteConversation:(LYRConversation *)conversation
{
    NSManagedObject *managedConversation = [self.objectCache managedObjectWithEntity:self.conversationEntity layerIdentifier:conversation.identifier];
    if (managedConversation) {
        [self.synchronizerContext deleteObject:managedConversation];
        
        if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didDeleteManagedObject:forLayerObject:)]) {
            [self.delegate layerObjectChangeSynchronizer:self didDeleteManagedObject:managedConversation forLayerObject:conversation];
        }
    }
}

- (void)createMessage:(LYRMessage *)message
{
    NSManagedObject *managedMessage = [[NSManagedObject alloc] initWithEntity:self.messageEntity insertIntoManagedObjectContext:self.synchronizerContext];
    [self updateManagedMessage:managedMessage fromLayerMessage:message change:nil];
    
    NSManagedObject *managedConversation = [self.objectCache managedObjectWithEntity:self.conversationEntity layerIdentifier:message.conversation.identifier];
    NSAssert(managedConversation, @"Conversation should not be nil.");
    [managedMessage setValue:managedConversation forKey:@"conversation"];
    
    if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didCreateManagedObject:forLayerObject:)]) {
        [self.delegate layerObjectChangeSynchronizer:self didCreateManagedObject:managedMessage forLayerObject:message];
    }
}

- (void)updateMessage:(LYRMessage *)message change:(NSDictionary *)change
{
    NSManagedObject *managedMessage = [self.objectCache managedObjectWithEntity:self.messageEntity layerIdentifier:message.identifier];
    NSAssert(managedMessage, @"Message should not be nil.");
    [self updateManagedMessage:managedMessage fromLayerMessage:message change:change];
    
    if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didUpdateManagedObject:withChange:forLayerObject:)]) {
        [self.delegate layerObjectChangeSynchronizer:self didUpdateManagedObject:managedMessage withChange:change forLayerObject:message];
    }
}

- (void)deleteMessage:(LYRMessage *)message
{
    NSManagedObject *managedMessage = [self.objectCache managedObjectWithEntity:self.messageEntity layerIdentifier:message.identifier];
    if (managedMessage) {
        [self.synchronizerContext deleteObject:managedMessage];
        
        if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didDeleteManagedObject:forLayerObject:)]) {
            [self.delegate layerObjectChangeSynchronizer:self didDeleteManagedObject:managedMessage forLayerObject:message];
        }
    }
}

- (void)updateManagedConversation:(NSManagedObject *)managedConversation fromLayerConversation:(LYRConversation *)conversation change:(NSDictionary *)change
{
    if (change == nil || [change[LYRObjectChangePropertyKey] isEqualToString:@"identifier"]) {
        [managedConversation setValue:[conversation.identifier absoluteString] forKey:@"identifier"];
    }
    
    if (change == nil || [change[LYRObjectChangePropertyKey] isEqualToString:@"createdAt"]) {
        [managedConversation setValue:conversation.createdAt forKey:@"createdAt"];
    }
    
    if (change == nil || [change[LYRObjectChangePropertyKey] isEqualToString:@"lastMessage"]) {
        if (conversation.lastMessage) {
            NSManagedObject *lastMessage = [self.objectCache managedObjectWithEntity:self.messageEntity layerIdentifier:conversation.lastMessage.identifier];
            [self updateManagedMessage:lastMessage fromLayerMessage:conversation.lastMessage change:nil];
            [lastMessage setValue:managedConversation forKey:@"conversation"];
            [managedConversation setValue:lastMessage forKey:@"lastMessage"];
        }
    }
    
}

- (void)updateManagedMessage:(NSManagedObject *)managedMessage fromLayerMessage:(LYRMessage *)message change:(NSDictionary *)change
{
    if (change == nil || [change[LYRObjectChangePropertyKey] isEqualToString:@"identifier"]) {
        [managedMessage setValue:[message.identifier absoluteString] forKey:@"identifier"];
    }
    
    if (change == nil || [change[LYRObjectChangePropertyKey] isEqualToString:@"index"]) {
        [managedMessage setValue:@(message.index) forKey:@"index"];
    }
    
    if (change == nil || [change[LYRObjectChangePropertyKey] isEqualToString:@"isSent"]) {
        [managedMessage setValue:@(message.isSent) forKey:@"isSent"];
    }
    
    if (change == nil || [change[LYRObjectChangePropertyKey] isEqualToString:@"receivedAt"]) {
        [managedMessage setValue:message.receivedAt forKey:@"receivedAt"];
    }
    
    if (change == nil || [change[LYRObjectChangePropertyKey] isEqualToString:@"sentAt"]) {
        [managedMessage setValue:message.sentAt forKey:@"sentAt"];
    }
    
    if (change == nil || [change[LYRObjectChangePropertyKey] isEqualToString:@"sentByUserID"]) {
        [managedMessage setValue:message.sentByUserID forKey:@"sentByUserID"];
    }
}

@end


@interface LayerObjectIdentifierCache ()
@property (nonatomic) dispatch_queue_t dispatchQueue;
@property (nonatomic) NSManagedObjectContext *managedObjectContext;
@property (nonatomic) NSMutableDictionary *layerIdentifiersToManagedObjectIDs;
@end

@implementation LayerObjectIdentifierCache

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    self = [super init];
    if (self) {
        _dispatchQueue = dispatch_queue_create("com.layer.LYRCoreData.LayerObjectIdentifierCache", DISPATCH_QUEUE_SERIAL);
        _managedObjectContext = managedObjectContext;
        _layerIdentifiersToManagedObjectIDs = [NSMutableDictionary new];
    }
    return self;
}

- (id)init
{
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:[NSString stringWithFormat:@"Failed to call designated initializer: call `%@` instead.",
                                           NSStringFromSelector(@selector(initWithManagedObjectContext:))]
                                 userInfo:nil];
}

- (NSManagedObject *)managedObjectWithEntity:(NSEntityDescription *)entity layerIdentifier:(NSURL *)layerObjectIdentifier
{
    NSManagedObjectID *managedObjectID = self.layerIdentifiersToManagedObjectIDs[layerObjectIdentifier];
    if (managedObjectID) {
        return [self.managedObjectContext objectWithID:managedObjectID];
    } else {
        static NSPredicate *predicateTemplate;
        if (!predicateTemplate) {
            predicateTemplate = [NSPredicate predicateWithFormat:@"identifier == $identifier"];
        }
        NSFetchRequest *fetchRequest = [NSFetchRequest new];
        fetchRequest.entity = entity;
        fetchRequest.fetchLimit = 1;
        fetchRequest.predicate = [predicateTemplate predicateWithSubstitutionVariables:@{ @"identifier": [layerObjectIdentifier absoluteString] }];
        
        NSError *error = nil;
        NSArray *objects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (!objects) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"Failed executing fetch request: %@", error]
                                         userInfo:nil];
        }
        
        if ([objects count]) {
            return [objects firstObject];
        } else {
            NSManagedObject *managedObject = [[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:self.managedObjectContext];
            self.layerIdentifiersToManagedObjectIDs[layerObjectIdentifier] = managedObject.objectID;
            return managedObject;
        }
    }
}

@end
