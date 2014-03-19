//
//  FireSuite.m
//
//  Created by Logan Wright on 3/12/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "FireSuite.h"

@implementation FireSuite

#pragma mark GET MANAGERS

+ (FSChatManager *) chatManager {
    return [FSChatManager singleton];
}

+ (FSChannelManager *) channelManager {
    return [FSChannelManager singleton];
}

+ (FSPresenceManager *) presenceManager {
    return [FSPresenceManager singleton];
}

#pragma mark SET URL & CURRENT USER ID

+ (void) setFirebaseURL:(NSString *)firebaseURL {
    if (![firebaseURL hasSuffix:@"/"]) {
        firebaseURL = [NSString stringWithFormat:@"%@/", firebaseURL];
    }
    
    // Set Our Tools
    [FSChatManager singleton].urlRefString = firebaseURL;
    [FSPresenceManager singleton].urlRefString = firebaseURL;
    [FSChannelManager singleton].urlRefString = firebaseURL;
}

+ (void) setCurrentUserId:(NSString *)currentUserId {
    
    // Set Our Tools
    [FSChatManager singleton].currentUserId = currentUserId;
    [FSPresenceManager singleton].currentUserId = currentUserId;
    [FSChannelManager singleton].currentUserId = currentUserId;
}

@end
