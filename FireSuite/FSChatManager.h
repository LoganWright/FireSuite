//
//  FSChatManager.h
//  ChatPhantom
//
//  Created by Logan Wright on 3/8/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Firebase/Firebase.h>

#import "FSChannelManager.h"

#define TimeStamp [NSString stringWithFormat:@"%f",[[NSDate new] timeIntervalSince1970] * 1000]

@protocol FSChatManagerDelegate

/*!

 */
- (void) newMessageReceived:(NSMutableDictionary *)newMessage;

@end

/*!
 Used To Monitor A P2P Chat Session
 */
@interface FSChatManager : NSObject

+ (FSChatManager *) singleton;

/*!
 Used to receive callbacks for incoming message stream.
 */
@property (strong, nonatomic) id<FSChatManagerDelegate>delegate;

/*!
 Number Of Messages To Receive On Initial Load
 */
@property (strong, nonatomic) NSNumber * maxCount;

/*!
 Your Firebase URL -- Will be appended to yourfirebase.firebaseio.com/Chats/%@(chatId)/etc.
 */
@property (strong, nonatomic) NSString * urlRefString;

/*!
 Current User's Id
 */
@property (strong, nonatomic) NSString * currentUserId;

/*!
 The ChatId For This Session
 */
@property (strong, nonatomic) NSString * chatId;

/*!
 Do Not Set This Property!
 */
@property (strong, nonatomic) NSArray * users;

#pragma mark NEW CHAT

- (void) createNewChatForUsers:(NSArray *)chatters withCustomId:(NSString *)customId andCompletionBlock:(void (^)(NSString * newChat, NSError * error))completion;;

#pragma mark HEADERS QUERY

- (void) addUserId:(NSString *)userId
          toChatId:(NSString *)chattId
withCompletionBlock:(void (^)(NSString * chatId, NSError * error))completion;

/*!
 Get All ChatHeaders
 */
- (void) getChatHeadersWithCompletionBlock:(void (^)(NSArray * messages, NSError * error))completion;

#pragma mark CHAT SESSION

/*!
 Used To Start New Session * SET URLREF & CHATID BEFORE CALLING THIS!! * -- Callback is array of recent messages.  Incoming messages will be received through delegate callback.
 */
- (void) loadChatSessionWithCompletionBlock:(void (^)(NSArray * messages, NSError * error))completion;

/*!
 Use this to end chat session before loading a new one!
 */
- (void) endChatSessionWithCompletionBlock:(void (^)(void))completion;


#pragma mark SEND MESSAGE

/*!
 Use to send a new message.
 */
- (void) sendNewMessage:(NSString *)content;

@end
