//
//  ViewController.m
//  FireSuite
//
//  Created by Logan Wright on 3/14/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Step 1: Launch Fire Suite
    
#pragma mark - INITIALIZE FIRESUITE
    
    [FireSuite setFirebaseURL:@"https://someFirebase.firebaseIO.com/"];
    [FireSuite setCurrentUserId:@"currentUserId"];
    
    // *** //
    
#pragma mark PRESENCE MANAGER
    
    // Step 2: Set Up Presence Manager
    //
    // Do not initialize any other way!
    //
    FSPresenceManager * presenceManager = [FireSuite presenceManager];
    
    // Start Monitor
    [presenceManager startPresenceManager];
    
    // Monitor Current User's Connection
    [presenceManager registerConnectionStatusObserver:self withSelector:@selector(isConnected:)];
    
    // Monitor Other Users (for instance, a chat opponent)
    [presenceManager registerUserStatusObserver:self
                                   withSelector:@selector(userStatusDidUpdateWithId:andStatus:)
                                      forUserId:@"anotherUserId"];
    [presenceManager registerUserStatusObserver:self
                                   withSelector:@selector(userStatusDidUpdateWithId:andStatus:)
                                      forUserId:@"yetAnotherUserId"];
    
    
#pragma mark CHANNEL MANAGER
    
    // Get Channel Manager
    FSChannelManager * channelManager = [FireSuite channelManager];
    
    // Observe Current User's Alert's Channel -- To receive any data you'd like to send ...
    [channelManager registerUserAlertsObserver:self withSelector:@selector(receivedAlert:)];
    
    // To send an alert
    NSMutableDictionary * alertData = [NSMutableDictionary new];
    alertData[@"some"] = @"random";
    alertData[@"data"] = @"here";
    [channelManager sendAlertToUserId:@"currentUserId" withAlertType:@"someAlertType" andData:alertData withCompletion:^(NSError * error) {
        if (!error) {
            NSLog(@"Alert Sent");
        }
        else {
            NSLog(@"ERROR: %@", error);
        }
    }];
    
#pragma mark CHAT MANAGER
    
    FSChatManager * chatManager = [FireSuite chatManager];
    
    // Create
    
    // Set CustomId to nil for AutoId
    [chatManager createNewChatForUsers:@[@"currentUserId", @"anotherUserId"] withCustomId:nil andCompletionBlock:^(NSString *newChatId, NSError *error) {
        NSLog(@"Created New Chat With Id: %@", newChatId);
        [self launchNewChatSessionForChatId:newChatId];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void) launchNewChatSessionForChatId:(NSString *)chatId {
    FSChatManager * chatManager = [FireSuite chatManager];
    chatManager.delegate = self; // who to send the messages
    [chatManager loadChatSessionWithChatId:chatId andNumberOfRecentMessages:50];
    
}
- (void) endChat {
    [[FireSuite chatManager] endChatSessionWithCompletionBlock:^(NSError *error) {
        if (!error) {
            // ended successfully
        }
        else {
            NSLog(@"Failed To End Session: %@", error);
        }
    }];
}

#pragma mark CHAT MANAGER DELEGATE

- (void) newMessageReceived:(NSMutableDictionary *)newMessage {
    NSLog(@"Received New Message: %@", newMessage);
}

- (void) chatSessionLoadDidFinishWithResponse:(NSDictionary *)response {
    NSDictionary * header = response[kResponseHeader];
    NSArray * retrievedMessages = response[kResponseMessages];
    
    NSLog(@"Retrieved Header: %@ andMessages: %@", header, retrievedMessages);
}

- (void) chatSessionLoadDidFailWithError:(NSError*)error {
    NSLog(@"loadDidFail: %@", error);
}

- (void) sendMessageDidFailWithError:(NSError *)error {
     NSLog(@"sendMessageDidFail: %@", error);
}

#pragma mark CHANNEL MANAGER CALLBACKS

// Used to receive alerts, for sending data from user to user ...
- (void) receivedAlert:(NSDictionary *)alert {
    NSString * alertType = alert[kAlertType];
    id alertData = alert[kAlertData];
    double timestamp = [alert[kAlertTimestamp] doubleValue] / 1000;
    NSDate * sentAt = [NSDate dateWithTimeIntervalSince1970:timestamp];
    
    NSLog(@"Received alert sentAt: %@ alertType: %@ withData: %@", sentAt, alertType, alertData);
}

#pragma mark PRESENCE MANAGER CALLBACKS

// Whether or not current user is connected to firebase.

- (void) isConnected:(BOOL)isConnected {
    NSLog(@"Current User %@ Firebase", isConnected ? @"Connected To": @"Disconnected From");
}

// Use this to monitor chat partners or whoever to see if they're online

- (void) userStatusDidUpdateWithId:(NSString *)userId andStatus:(BOOL)isOnline {
    NSLog(@"%@ is currently: %@", userId, isOnline ? @"Online": @"Offline");
}

@end
