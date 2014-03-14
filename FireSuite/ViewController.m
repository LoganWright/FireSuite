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
    
#pragma mark FIRE SUITE
    
    //  *** // - Call this before using any other aspects!
    
    NSString * firebaseMainURL = @"https://someFirebase.firebaseIO.com/";
    FireSuite * fireSuite = [FireSuite singleton];
    fireSuite.firebaseURL = firebaseMainURL;
    fireSuite.currentUserId = @"currentUserId";
    
    // *** //
    
#pragma mark PRESENCE
    
    // Step 2: Set Up Presence Manager
    //
    // Do not initialize any other way!
    //
    FSPresenceManager * presenceManager = fireSuite.presenceManager;
    
    // Start Monitor
    [presenceManager startPresenceManager];
    
    // Monitor Current User's Connection
    [presenceManager registerConnectionStatusObserver:self withSelector:@selector(isConnected:)];
    
    // Monitor Other Users (for instance, a chat opponent)
    [presenceManager registerUserStatusObserver:self
                                   withSelector:@selector(userStatusDidUpdateWithId:andStatus:)
                                      forUserId:@"userId1"];
    [presenceManager registerUserStatusObserver:self
                                   withSelector:@selector(userStatusDidUpdateWithId:andStatus:)
                                      forUserId:@"userId2"];
    
    
#pragma mark CHANNEL MANAGER
    
    // Get Channel Manager
    FSChannelManager * channelManager = [FireSuite singleton].channelManager;
    
    // Observe Current User's Alert's Channel
    //
    // receivedAlert will be an nsdictionary
    //
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
    
    FSChatManager * chatManager = fireSuite.chatManager;
    
    // Create
    
    // Set CustomId to nil for AutoId
    
    [chatManager createNewChatForUsers:@[@"user1id", @"user2id"] withCustomId:nil andCompletionBlock:^(NSString *newChatId, NSError *error) {
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
    FireSuite * fireSuite = [FireSuite singleton];
    FSChatManager * chatManager = fireSuite.chatManager;
    chatManager.chatId = chatId; // chat id of new session
    chatManager.delegate = self; // who to send the messages
    chatManager.maxCount = [NSNumber numberWithInt:50]; // number of initial recent messages to receive
    [chatManager loadChatSessionWithCompletionBlock:^(NSArray *messages, NSError *error) {
        if (!error) {
            NSLog(@"Open with recent messages: %@", messages);
            // receivedNewMessage: will begin running now.
        }
        else {
            NSLog(@"Error: %@", error);
        }
    }];
}

- (void) endChat {
    FireSuite * fireSuite = [FireSuite singleton];
    FSChatManager * chatManager = fireSuite.chatManager;
    
    [chatManager endChatSessionWithCompletionBlock:^{
        NSLog(@"Closed Current Chat Session");
    }];
}

#pragma mark CHAT MANAGER DELEGATE

- (void) newMessageReceived:(NSMutableDictionary *)newMessage {
    NSLog(@"Received new message: %@", newMessage);
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

#pragma mark PRESENCE MANAGER

// Whether or not current user is connected to firebase.

- (void) isConnected:(BOOL)isConnected {
    NSLog(@"Current User %@ firebase", isConnected ? @"Connected To": @"Disconnected From");
}

// Use this to monitor chat partners or whoever to see if they're online

- (void) userStatusDidUpdateWithId:(NSString *)userId andStatus:(BOOL)isOnline {
    NSLog(@"%@ is currently: %@", userId, isOnline ? @"Online": @"Offline");
}

@end
