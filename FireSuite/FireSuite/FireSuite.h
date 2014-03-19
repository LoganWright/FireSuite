//
//  FireSuite.h
//
//  Created by Logan Wright on 3/12/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FSChatManager.h"
#import "FSPresenceManager.h"
#import "FSChannelManager.h"

@interface FireSuite : NSObject

+ (void) setFirebaseURL:(NSString *)firebaseURL;
+ (void) setCurrentUserId:(NSString *)currentUserId;

+ (FSChatManager *) chatManager;
+ (FSPresenceManager *) presenceManager;
+ (FSChannelManager *) channelManager;

@end
