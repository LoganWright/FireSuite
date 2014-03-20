//
//  FSChatManager.h
//
//  Created by Logan Wright on 3/8/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Firebase/Firebase.h>

#pragma mark CONSTANTS

typedef enum {
    FSChatErrorAlreadyInUse = 101,
    FSChatErrorFailedToGetHeader = 202,
} FSChatErrorCode;

// Response Keys
FOUNDATION_EXPORT NSString *const kResponseMessages;
FOUNDATION_EXPORT NSString *const kResponseHeader;

// Error Keys
FOUNDATION_EXPORT NSString * const kFSChatManagerErrorDomain;
FOUNDATION_EXPORT NSString * const kErrorFailedToGetHeader;
FOUNDATION_EXPORT NSString * const kErrorAlreadyInUse;

// Chat Keys
FOUNDATION_EXPORT NSString *const kChatHeader;
FOUNDATION_EXPORT NSString *const kChatMessages;
FOUNDATION_EXPORT NSString *const kChatCreatedAt;
FOUNDATION_EXPORT NSString *const kChatUsers;

// Header Keys
FOUNDATION_EXPORT NSString *const kHeaderLastMessage;
FOUNDATION_EXPORT NSString *const kHeaderTimeStamp;
FOUNDATION_EXPORT NSString *const kHeaderCreatedAt;
FOUNDATION_EXPORT NSString *const kHeaderUsers;

// Message Keys
FOUNDATION_EXPORT NSString *const kMessageSentTo;
FOUNDATION_EXPORT NSString *const kMessageSentBy;
FOUNDATION_EXPORT NSString *const kMessageContent;
FOUNDATION_EXPORT NSString *const kMessageTimestamp;
FOUNDATION_EXPORT NSString *const kMessageHasViewed;
FOUNDATION_EXPORT NSString *const kMessageChatId;

/*
 Firebase Priority Doesn't Calculate Decimals in priorities, Multiply By 1000 To Expose Milliseconds and have more accurate priorities!
 */
#define TimeStamp [NSString stringWithFormat:@"%f",[[NSDate new] timeIntervalSince1970] * 1000]

@protocol FSChatManagerDelegate

/*!
 Attempt to load chat succeeded with messages -
 */
@required - (void) chatSessionLoadDidFinishWithResponse:(NSDictionary *)response;
/*!
 Attempt to load chat failed
 */
@required - (void) chatSessionLoadDidFailWithError:(NSError*)error;

/*!
 Used to notify of a failed message send
 */
@required - (void) sendMessage:(NSDictionary *)message didFailWithError:(NSError *)error;

/*!
 A new message has been received -- will fire continually
 */
@required - (void) newMessageReceived:(NSMutableDictionary *)newMessage;

@end

/*!
 Used To Monitor A P2P Chat Session
 */
@interface FSChatManager : NSObject

/*!
 The Chat Manager
 */
+ (instancetype) singleton;

/*!
 Used to receive callbacks for incoming message stream -- must adhere to FSChatManagerDelegate Protocol
 */
@property (strong, nonatomic) id<FSChatManagerDelegate>delegate;

/*!
 Your Firebase URL -- Will be appended to yourfirebase.firebaseio.com/Chats/%@(chatId)/etc.
 */
@property (strong, nonatomic) NSString * urlRefString;
/*!
 Current User's Id
 */
@property (strong, nonatomic) NSString * currentUserId;

/*!
 Current ChatId
 */
@property (strong, nonatomic) NSString * chatId;

#pragma mark CREATE NEW CHAT

/*!
 Create a new chat for @param users - array of 2 user Id's @param customId - a customId to assign the chat.  Will auto-assign id if set to nil.
 */
- (void) createNewChatForUsers:(NSArray *)users
                  withCustomId:(NSString *)customId
            andCompletionBlock:(void (^)(NSString * newChatId, NSError * error))completion;

#pragma mark ADD USER TO CHAT

/*!
 Add $userId to $chatId
 */
- (void) addUserId:(NSString *)userId
          toChatId:(NSString *)chatId
withCompletionBlock:(void (^)(NSString * chatId, NSError * error))completion;

#pragma mark HEADERS QUERY

/*!
 Get All ChatHeaders
 */
- (void) getChatHeadersWithCompletionBlock:(void (^)(NSArray * headers, NSError * error))completion;

#pragma mark CHAT SESSION

/*!
 Used To Start New Session -- Make Sure Delegate Is Registered
 */
- (void) loadChatSessionWithChatId:(NSString *)chatId andNumberOfRecentMessages:(int)numberOfMessages;

/*!
 Use this to end chat session before loading a new one!
 */
- (void) endChatSessionWithCompletionBlock:(void (^)(NSError * error))completion;

#pragma mark SEND MESSAGE

/*!
 Use to send a new message. -- Timestamp, SentBy, SentTo, ChatId
 */
- (void) sendNewMessage:(NSString *)content;

@end
