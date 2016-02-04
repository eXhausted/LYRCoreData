//
//  WKCoreDataStack.h
//  Wayke
//
//  Created by Bogdan Geleta on 11/5/15.
//  Copyright © 2015 Softheme. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreData;
//#import "NSManagedObject+WK.h"

@interface WKCoreDataStack : NSObject

+ (instancetype)sharedStack;

- (void)setupStack;
- (void)saveWithBlockAndWait:(void (^)(NSManagedObjectContext *localContext))block;

+ (void)saveWithBlockAndWait:(void (^)(NSManagedObjectContext *localContext))block;
+ (void)cleanUp;

@property (nonatomic, readonly) NSManagedObjectContext *mainContext;
@property (nonatomic, readonly) NSManagedObjectContext *backgroundContext;
+ (NSManagedObjectContext *)mainContext;
+ (NSManagedObjectContext *)backgroundContext;

@end
