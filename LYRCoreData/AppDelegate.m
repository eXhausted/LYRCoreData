//
//  AppDelegate.m
//  LYRCoreData
//
//  Created by Blake Watters on 9/20/14.
//  Copyright (c) 2014 Layer. All rights reserved.
//

#import <LayerKit/LayerKit.h>
#import "AppDelegate.h"
#import "WKCoreDataStack.h"
#import "LayerObjectChangeSynchronizer.h"
#import "ConversationViewController.h"
#import "ConversationsListViewController.h"

#warning Fill with your key/id
NSString *const kLayerApplicationID = @"LAYER_APP_ID";
NSString *const kLayerUserID        = @"LAYER_USER_ID";

@interface AppDelegate ()

@property (nonatomic) WKCoreDataStack *coreDataStack;
@property (nonatomic) LYRClient *layerClient;
@property (nonatomic) LayerObjectChangeSynchronizer *objectChangeSynchronizer;
@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Initialize Core Data
    self.coreDataStack = [WKCoreDataStack sharedStack];
    [self.coreDataStack setupStack];
    
    // Initialize Layer & authenticate
    self.layerClient = [LYRClient clientWithAppID:[NSURL URLWithString:kLayerApplicationID]];
    
    // Configure the object change synchronizer
    _objectChangeSynchronizer = [[LayerObjectChangeSynchronizer alloc] initWithLayerClient:self.layerClient];
    
    // Authenticate Layer
    [self.layerClient connectWithCompletion:^(BOOL success, NSError *error) {
        if (!success) {
            LYRLog(@"Failed to connect to Layer: %@", error);
            abort();
            return;
        }
        
        if (!self.layerClient.authenticatedUserID) {
            [self.layerClient requestAuthenticationNonceWithCompletion:^(NSString *nonce, NSError *error) {
                if (!nonce) {
                    LYRLog(@"Request for Layer authentication nonce failed: %@", error);
                    abort();
                    return;
                }
                
                NSURL *identityTokenURL = [NSURL URLWithString:@"https://layer-identity-provider.herokuapp.com/identity_tokens"];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:identityTokenURL];
                request.HTTPMethod = @"POST";
                [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
                NSDictionary *parameters = @{ @"app_id": kLayerApplicationID, @"user_id": kLayerUserID, @"nonce": nonce };
                __block NSError *serializationError = nil;
                NSData *requestBody = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&serializationError];
                if (!requestBody) {
                    LYRLog(@"Failed serialization of request parameters: %@", serializationError);
                    abort();
                    return;
                }
                request.HTTPBody = requestBody;
                
                NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
                NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
                [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                    if (!data) {
                        LYRLog(@"Failed requesting identity token: %@", error);
                        abort();
                        return;
                    }
                    
                    NSDictionary *responseObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&serializationError];
                    if (!responseObject) {
                        LYRLog(@"Failed deserialization of response: %@", serializationError);
                        abort();
                        return;
                    }
                    
                    NSString *identityToken = responseObject[@"identity_token"];
                    [self.layerClient authenticateWithIdentityToken:identityToken completion:^(NSString *authenticatedUserID, NSError *error) {
                        if (!authenticatedUserID) {
                            LYRLog(@"Failed auithenticaiton with Layer: %@", error);
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
    controller.managedObjectContext = self.coreDataStack.mainContext;
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
}

@end
