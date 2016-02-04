//
//  LayerObjectChangeSynchronizer.m
//  LYRCoreData
//
//  Created by Blake Watters on 9/20/14.
//  Copyright (c) 2014 Layer. All rights reserved.
//

#import "LayerObjectChangeSynchronizer.h"
#import "WKCoreDataStack.h"

@interface LayerObjectIdentifierCache : NSObject

- (NSManagedObject *)managedObjectWithEntity:(NSEntityDescription *)entity layerIdentifier:(NSURL *)layerObjectIdentifier inManagedObjectContext:(NSManagedObjectContext *)context;

@end

@interface LayerObjectChangeSynchronizer ()
@property (nonatomic) LYRClient *layerClient;
@property (nonatomic) NSOperationQueue *operationQueue;
@property (nonatomic) LayerObjectIdentifierCache *objectCache;
@end

@implementation LayerObjectChangeSynchronizer

- (id)init {
    @throw [NSException exceptionWithName:NSInvalidArgumentException
                                   reason:[NSString stringWithFormat:@"Failed to call designated initializer: call `%@` instead.",
                                           NSStringFromSelector(@selector(initWithLayerClient:))]
                                 userInfo:nil];
}

- (id)initWithLayerClient:(LYRClient *)layerClient {
    NSParameterAssert(layerClient);
    //NSParameterAssert(managedObjectContext);
    self = [super init];
    if (self) {
        _layerClient = layerClient;
        _operationQueue = [NSOperationQueue new];
        _operationQueue.maxConcurrentOperationCount = 1;
        _objectCache = [[LayerObjectIdentifierCache alloc] init];
        _conversationEntity = [NSEntityDescription entityForName:@"Conversation" inManagedObjectContext:[WKCoreDataStack backgroundContext]];
        _messageEntity = [NSEntityDescription entityForName:@"Message" inManagedObjectContext:[WKCoreDataStack backgroundContext]];
        _messagePartEntity = [NSEntityDescription entityForName:@"MessagePart" inManagedObjectContext:[WKCoreDataStack backgroundContext]];
        
        // Register for notifications
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveLayerClientObjectsDidChangeNotification:) name:LYRClientObjectsDidChangeNotification object:layerClient];        
    }
    return self;
}

- (void)didReceiveLayerClientObjectsDidChangeNotification:(NSNotification *)notification {
    [self.operationQueue addOperationWithBlock:^{
        [WKCoreDataStack saveWithBlockAndWait:^(NSManagedObjectContext *localContext) {
            NSArray *changes = [notification.userInfo objectForKey:LYRClientObjectChangesUserInfoKey];
            for (LYRObjectChange *change in changes) {
                LYRLog(@"Synchronizing %@", change);
                id changeObject = change.object;
                LYRObjectChangeType updateKey = change.type;
                switch (updateKey) {
                    case LYRObjectChangeTypeCreate: {
                        if ([changeObject isKindOfClass:[LYRConversation class]]) {
                            [self createConversation:changeObject inManagedObjectContext:localContext];
                        } else if ([changeObject isKindOfClass:[LYRMessage class]]) {
                            [self createMessage:changeObject inManagedObjectContext:localContext];
                        } else if ([changeObject isKindOfClass:[LYRMessagePart class]]){
                            [self createMessagePart:changeObject inManagedObjectContext:localContext];
                        } else {
                            [NSException raise:NSInternalInconsistencyException format:@"Cannot synchronize object change: Unable to handle objects of type '%@' (change=%@)", [changeObject class], change];
                        }
                        break;
                    }
                    case LYRObjectChangeTypeUpdate: {
                        if ([changeObject isKindOfClass:[LYRConversation class]]) {
                            [self updateConversation:changeObject change:change inManagedObjectContext:localContext];
                        } else if ([changeObject isKindOfClass:[LYRMessage class]]) {
                            [self updateMessage:changeObject change:change inManagedObjectContext:localContext];
                        } else if ([changeObject isKindOfClass:[LYRMessagePart class]]){
                            [self updateMessagePart:changeObject change:change inManagedObjectContext:localContext];
                        } else {
                            [NSException raise:NSInternalInconsistencyException format:@"Cannot synchronize object change: Unable to handle objects of type '%@' (change=%@)", [changeObject class], change];
                        }
                        break;
                    }
                    case LYRObjectChangeTypeDelete: {
                        if ([changeObject isKindOfClass:[LYRConversation class]]) {
                            [self deleteConversation:changeObject inManagedObjectContext:localContext];
                        } else if ([changeObject isKindOfClass:[LYRMessage class]]) {
                            [self deleteMessage:changeObject inManagedObjectContext:localContext];
                        } else if ([changeObject isKindOfClass:[LYRMessagePart class]]){
                            [self deleteMessagePart:changeObject inManagedObjectContext:localContext];
                        } else {
                            [NSException raise:NSInternalInconsistencyException format:@"Cannot synchronize object change: Unable to handle objects of type '%@' (change=%@)", [changeObject class], change];
                        }
                        break;
                    }
                    default:
                        break;
                }
            }
        }];
    }];
}

- (void)suspend {
    self.operationQueue.suspended = YES;
}

- (void)resume {
    self.operationQueue.suspended = NO;
}

- (BOOL)isSuspended {
    return self.operationQueue.isSuspended;
}

#pragma mark - Private methods
#pragma mark - Converation

- (void)createConversation:(LYRConversation *)conversation inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObject *managedConversation = [[NSManagedObject alloc] initWithEntity:self.conversationEntity insertIntoManagedObjectContext:context];
    [self updateManagedConversation:managedConversation fromLayerConversation:conversation change:nil inManagedObjectContext:context];
    
    if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didCreateManagedObject:forLayerObject:)]) {
        [self.delegate layerObjectChangeSynchronizer:self didCreateManagedObject:managedConversation forLayerObject:conversation];
    }
}

- (void)updateConversation:(LYRConversation *)conversation change:(LYRObjectChange *)change inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObject *managedConversation = [self.objectCache managedObjectWithEntity:self.conversationEntity layerIdentifier:conversation.identifier inManagedObjectContext:context];
    NSAssert(managedConversation, @"Conversation should not be nil.");
    [self updateManagedConversation:managedConversation fromLayerConversation:conversation change:change inManagedObjectContext:context];
    
    if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didUpdateManagedObject:withChange:forLayerObject:)]) {
        [self.delegate layerObjectChangeSynchronizer:self didUpdateManagedObject:managedConversation withChange:nil forLayerObject:conversation];
    }
}

- (void)deleteConversation:(LYRConversation *)conversation inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObject *managedConversation = [self.objectCache managedObjectWithEntity:self.conversationEntity layerIdentifier:conversation.identifier inManagedObjectContext:context];
    if (managedConversation) {
        [context deleteObject:managedConversation];
        
        if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didDeleteManagedObject:forLayerObject:)]) {
            [self.delegate layerObjectChangeSynchronizer:self didDeleteManagedObject:managedConversation forLayerObject:conversation];
        }
    }
}

#pragma mark - Message

- (void)createMessage:(LYRMessage *)message inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObject *managedMessage = [[NSManagedObject alloc] initWithEntity:self.messageEntity insertIntoManagedObjectContext:context];
    [self updateManagedMessage:managedMessage fromLayerMessage:message change:nil];
    
    NSManagedObject *managedConversation = [self.objectCache managedObjectWithEntity:self.conversationEntity layerIdentifier:message.conversation.identifier inManagedObjectContext:context];
    NSAssert(managedConversation, @"Conversation should not be nil.");
    [managedMessage setValue:managedConversation forKey:@"conversation"];
    
    if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didCreateManagedObject:forLayerObject:)]) {
        [self.delegate layerObjectChangeSynchronizer:self didCreateManagedObject:managedMessage forLayerObject:message];
    }
}

- (void)updateMessage:(LYRMessage *)message change:(LYRObjectChange *)change inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObject *managedMessage = [self.objectCache managedObjectWithEntity:self.messageEntity layerIdentifier:message.identifier inManagedObjectContext:context];
    NSAssert(managedMessage, @"Message should not be nil.");
    [self updateManagedMessage:managedMessage fromLayerMessage:message change:change];
    
    if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didUpdateManagedObject:withChange:forLayerObject:)]) {
        [self.delegate layerObjectChangeSynchronizer:self didUpdateManagedObject:managedMessage withChange:nil forLayerObject:message];
    }
}

- (void)deleteMessage:(LYRMessage *)message inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObject *managedMessage = [self.objectCache managedObjectWithEntity:self.messageEntity layerIdentifier:message.identifier inManagedObjectContext:context];
    if (managedMessage) {
        [context deleteObject:managedMessage];
        
        if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didDeleteManagedObject:forLayerObject:)]) {
            [self.delegate layerObjectChangeSynchronizer:self didDeleteManagedObject:managedMessage forLayerObject:message];
        }
    }
}

#pragma mark - Message Part

- (void)createMessagePart:(LYRMessagePart *)messagePart inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObject *managedMessagePart = [[NSManagedObject alloc] initWithEntity:self.messagePartEntity insertIntoManagedObjectContext:context];
    [self updateManagedMessagePart:managedMessagePart fromLayerMessage:messagePart change:nil];
    
    NSManagedObject *managedMessage = [self.objectCache managedObjectWithEntity:self.messageEntity layerIdentifier:messagePart.message.identifier inManagedObjectContext:context];
    NSAssert(managedMessage, @"Message should not be nil.");
    [managedMessagePart setValue:managedMessage forKey:@"message"];
    
    if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didCreateManagedObject:forLayerObject:)]) {
        [self.delegate layerObjectChangeSynchronizer:self didCreateManagedObject:managedMessagePart forLayerObject:messagePart];
    }
}

- (void)updateMessagePart:(LYRMessagePart *)messagePart change:(LYRObjectChange *)change inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObject *managedMessagePart = [self.objectCache managedObjectWithEntity:self.messagePartEntity layerIdentifier:messagePart.identifier inManagedObjectContext:context];
    NSAssert(managedMessagePart, @"MessagePart should not be nil.");
    [self updateManagedMessagePart:managedMessagePart fromLayerMessage:messagePart change:change];
    
    if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didUpdateManagedObject:withChange:forLayerObject:)]) {
        [self.delegate layerObjectChangeSynchronizer:self didUpdateManagedObject:managedMessagePart withChange:nil forLayerObject:messagePart];
    }
}

- (void)deleteMessagePart:(LYRMessagePart *)messagePart inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObject *managedMessagePart = [self.objectCache managedObjectWithEntity:self.messagePartEntity layerIdentifier:messagePart.identifier inManagedObjectContext:context];
    if (managedMessagePart) {
        [context deleteObject:managedMessagePart];
        
        if ([self.delegate respondsToSelector:@selector(layerObjectChangeSynchronizer:didDeleteManagedObject:forLayerObject:)]) {
            [self.delegate layerObjectChangeSynchronizer:self didDeleteManagedObject:managedMessagePart forLayerObject:messagePart];
        }
    }
}

#pragma mark - Update

- (void)updateManagedConversation:(NSManagedObject *)managedConversation fromLayerConversation:(LYRConversation *)conversation change:(LYRObjectChange *)change inManagedObjectContext:(NSManagedObjectContext *)context {
    if (change == nil || [change.property isEqualToString:@"identifier"]) {
        [managedConversation setValue:[conversation.identifier absoluteString] forKey:@"identifier"];
    }
    
    if (change == nil || [change.property isEqualToString:@"createdAt"]) {
        [managedConversation setValue:conversation.createdAt forKey:@"createdAt"];
    }
    
    if (change == nil || [change.property isEqualToString:@"lastMessage"]) {
        if (conversation.lastMessage) {
            NSManagedObject *lastMessage = [self.objectCache managedObjectWithEntity:self.messageEntity layerIdentifier:conversation.lastMessage.identifier inManagedObjectContext:context];
            [self updateManagedMessage:lastMessage fromLayerMessage:conversation.lastMessage change:nil];
            [lastMessage setValue:managedConversation forKey:@"conversation"];
            [managedConversation setValue:lastMessage forKey:@"lastMessage"];
        }
    }
    
}

- (void)updateManagedMessage:(NSManagedObject *)managedMessage fromLayerMessage:(LYRMessage *)message change:(LYRObjectChange *)change {
    if (change == nil || [change.property isEqualToString:@"identifier"]) {
        [managedMessage setValue:[message.identifier absoluteString] forKey:@"identifier"];
    }
    
    if (change == nil || [change.property isEqualToString:@"index"]) {
        [managedMessage setValue:@(message.position) forKey:@"index"];
    }
    
    if (change == nil || [change.property isEqualToString:@"isSent"]) {
        [managedMessage setValue:@(message.isSent) forKey:@"isSent"];
    }
    
    if (change == nil || [change.property isEqualToString:@"receivedAt"]) {
        [managedMessage setValue:message.receivedAt forKey:@"receivedAt"];
    }
    
    if (change == nil || [change.property isEqualToString:@"sentAt"]) {
        [managedMessage setValue:message.sentAt forKey:@"sentAt"];
    }
    
    if (change == nil || [change.property isEqualToString:@"sentByUserID"]) {
        [managedMessage setValue:message.sender.userID forKey:@"senderID"];
    }
}

- (void)updateManagedMessagePart:(NSManagedObject *)managedMessage fromLayerMessage:(LYRMessagePart *)messagePart change:(LYRObjectChange *)change {
    if (change == nil || [change.property isEqualToString:@"identifier"]) {
        [managedMessage setValue:[messagePart.identifier absoluteString] forKey:@"identifier"];
    }
    
    if (change == nil || [change.property isEqualToString:@"data"]) {
        [managedMessage setValue:messagePart.data forKey:@"data"];
    }
    
    if (change == nil || [change.property isEqualToString:@"MIMEType"]) {
        [managedMessage setValue:messagePart.MIMEType forKey:@"mimeType"];
    }
}

@end


@interface LayerObjectIdentifierCache ()
@property (nonatomic) NSMutableDictionary *layerIdentifiersToManagedObjectIDs;
@end

@implementation LayerObjectIdentifierCache

- (id)init {
    self = [super init];
    if (self) {
        _layerIdentifiersToManagedObjectIDs = [NSMutableDictionary new];
    }
    return self;
}

- (NSManagedObject *)managedObjectWithEntity:(NSEntityDescription *)entity layerIdentifier:(NSURL *)layerObjectIdentifier inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObjectID *managedObjectID = self.layerIdentifiersToManagedObjectIDs[layerObjectIdentifier];
    if (managedObjectID) {
        return [context objectWithID:managedObjectID];
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
        NSArray *objects = [context executeFetchRequest:fetchRequest error:&error];
        if (!objects) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:[NSString stringWithFormat:@"Failed executing fetch request: %@", error]
                                         userInfo:nil];
        }
        
        if ([objects count]) {
            return [objects firstObject];
        } else {
            NSManagedObject *managedObject = [[NSManagedObject alloc] initWithEntity:entity insertIntoManagedObjectContext:context];
            self.layerIdentifiersToManagedObjectIDs[layerObjectIdentifier] = managedObject.objectID;
            return managedObject;
        }
    }
}

@end
