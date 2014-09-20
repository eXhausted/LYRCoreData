//
//  AppDelegate.m
//  LYRCoreData
//
//  Created by Blake Watters on 9/20/14.
//  Copyright (c) 2014 Layer. All rights reserved.
//

#import <LayerKit/LayerKit.h>
#import "AppDelegate.h"
#import "CoreDataStack.h"
#import "LayerObjectChangeSynchronizer.h"
#import "ConversationViewController.h"
#import "ConversationsListViewController.h"

@interface AppDelegate ()
@property (nonatomic) CoreDataStack *coreDataStack;
@property (nonatomic) LYRClient *layerClient;
@property (nonatomic) LayerObjectChangeSynchronizer *objectChangeSynchronizer;
@end

static NSURL *ApplicationDocumentsDirectory()
{
    // The directory the application uses to store the Core Data store file. This code uses a directory named "com.layer.LYRCoreData" in the application's documents directory.
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Initialize Core Data
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"LYRCoreData" withExtension:@"momd"];
    NSManagedObjectModel *managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    self.coreDataStack = [CoreDataStack stackWithManagedObjectModel:managedObjectModel];
    
    NSError *error = nil;
    NSURL *storeURL = [ApplicationDocumentsDirectory() URLByAppendingPathComponent:@"LYRCoreData.sqlite"];
    NSPersistentStore *store = [self.coreDataStack.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error];
    if (!store) {
        // Replace this with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
        return YES;
    }
    
    [self.coreDataStack createManagedObjectContexts];
    
    // Register for save notifications to merge changes saved to the persistence context back into the user interface
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveManagedObjectContextDidSaveNotification:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:self.coreDataStack.persistenceContext];
    
    // Initialize Layer & authenticate
    NSString *appIDString = [NSProcessInfo processInfo].environment[@"LAYER_APP_ID"];
    NSString *userID = [NSProcessInfo processInfo].environment[@"LAYER_USER_ID"];
    NSUUID *appID = [[NSUUID alloc] initWithUUIDString:appIDString];
    self.layerClient = [LYRClient clientWithAppID:appID];
    
    // Configure the object change synchronizer
    _objectChangeSynchronizer = [[LayerObjectChangeSynchronizer alloc] initWithLayerClient:self.layerClient managedObjectContext:self.coreDataStack.persistenceContext];
    
    // Authenticate Layer
    [self.layerClient connectWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            NSLog(@"Failed to connect to Layer: %@", error);
            abort();
            return;
        }
        
        if (!self.layerClient.authenticatedUserID) {
            [self.layerClient requestAuthenticationNonceWithCompletion:^(NSString *nonce, NSError *error) {
                if (!nonce) {
                    NSLog(@"Request for Layer authentication nonce failed: %@", error);
                    abort();
                    return;
                }
                
                NSURL *identityTokenURL = [NSURL URLWithString:@"https://layer-identity-provider.herokuapp.com/identity_tokens"];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:identityTokenURL];
                request.HTTPMethod = @"POST";
                [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
                NSDictionary *parameters = @{ @"app_id": appIDString, @"user_id": userID, @"nonce": nonce };
                __block NSError *serializationError = nil;
                NSData *requestBody = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&serializationError];
                if (!requestBody) {
                    NSLog(@"Failed serialization of request parameters: %@", serializationError);
                    abort();
                    return;
                }
                request.HTTPBody = requestBody;
                
                NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
                NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
                [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    if (!data) {
                        NSLog(@"Failed requesting identity token: %@", error);
                        abort();
                        return;
                    }
                    
                    NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&serializationError];
                    if (!responseObject) {
                        NSLog(@"Failed deserialization of response: %@", serializationError);
                        abort();
                        return;
                    }
                    
                    NSString *identityToken = responseObject[@"identity_token"];
                    [self.layerClient authenticateWithIdentityToken:identityToken completion:^(NSString *authenticatedUserID, NSError *error) {
                        if (!authenticatedUserID) {
                            NSLog(@"Failed auithenticaiton with Layer: %@", error);
                            abort();
                            return;
                        }
                    }];
                }] resume];
            }];
        }
    }];
    
    UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
    ConversationsListViewController *controller = (ConversationsListViewController *)navigationController.topViewController;
    controller.layerClient = self.layerClient;
    controller.managedObjectContext = self.coreDataStack.userInterfaceContext;
    return YES;
}

- (void)didReceiveManagedObjectContextDidSaveNotification:(NSNotification *)notification
{
    [self.coreDataStack.userInterfaceContext performBlock:^{
        [self.coreDataStack.userInterfaceContext mergeChangesFromContextDidSaveNotification:notification];
    }];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    [self.coreDataStack saveContexts:nil];
}

@end
