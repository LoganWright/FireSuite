//
//  FireSuite.m
//  ChatPhantom
//
//  Created by Logan Wright on 3/12/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "FireSuite.h"

@implementation FireSuite

@synthesize firebaseURL, currentUserId, presenceManager, chatManager, channelManager;

+ (FireSuite *) singleton {
    static dispatch_once_t pred;
    static FireSuite *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[FireSuite alloc] init];
    });
    return shared;
}

- (void) setFirebaseURL:(NSString *)firebaseURLsetter {
    
    if (![firebaseURLsetter hasSuffix:@"/"]) {
        firebaseURLsetter = [NSString stringWithFormat:@"%@/", firebaseURLsetter];
    }
    
    // Set Our Tools
    [FSChatManager singleton].urlRefString = firebaseURLsetter;
    [FSPresenceManager singleton].urlRefString = firebaseURLsetter;
    [FSChannelManager singleton].urlRefString = firebaseURLsetter;
    
    firebaseURL = firebaseURLsetter;
}

- (void) setCurrentUserId:(NSString *)currentUserIdToSet {
    
    // Set Our Tools
    [FSChatManager singleton].currentUserId = currentUserIdToSet;
    [FSPresenceManager singleton].currentUserId = currentUserIdToSet;
    [FSChannelManager singleton].currentUserId = currentUserIdToSet;
    
    currentUserId = currentUserIdToSet;
}

#pragma mark GETTERS

// Presence Manager
- (void) setPresenceManager:(FSPresenceManager *)presenceManagerToSet {
    NSLog(@"Don't Set Presence Manager");
    presenceManager = presenceManagerToSet;
}

- (FSPresenceManager *) presenceManager {
    FSPresenceManager * manager = [FSPresenceManager singleton];
    return manager;
}

- (FSChatManager *) chatManager {
    FSChatManager * manager = [FSChatManager singleton];
    return manager;
}

- (FSChannelManager *) channelManager {
    FSChannelManager * manager = [FSChannelManager singleton];
    return manager;
}

@end
