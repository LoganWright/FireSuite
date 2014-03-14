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

+ (FireSuite *) suiteManager;

@property (strong, nonatomic) NSString * firebaseURL;
@property (strong, nonatomic) NSString * currentUserId;

@property (strong, nonatomic) FSChatManager * chatManager;
@property (strong, nonatomic) FSPresenceManager * presenceManager;
@property (strong, nonatomic) FSChannelManager * channelManager;

@end
