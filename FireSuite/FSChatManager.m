//
//  FSChatManager.m
//
//  Created by Logan Wright on 3/8/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "FSChatManager.h"

static NSString * kMessageSentTo = @"sentTo";
static NSString * kMessageSentFrom = @"sentFrom";
static NSString * kMessageContent = @"content";
static NSString * kMessageTimestamp = @"timestamp";
static NSString * kMessageHasViewed = @"hasViewed";
static NSString * kMessageChatId = @"chatId";

static NSString * kHeaderLastMessage = @"lastMessage";
static NSString * kHeaderTimeStamp = @"timestamp";
static NSString * kHeaderCreatedAt = @"createdAt";

@interface FSChatManager ()
{
    Firebase * countRef;
    Firebase * messagesRef;
    Firebase * chatHeaderRef;
    
    FirebaseHandle queryHandle;
    FirebaseHandle messageMonitorHandle;
    
    NSMutableArray * receivedMessagesArray;
    
    int maxMessageCount;
    
    // Headers
    int headerCount;
    NSMutableArray * receivedHeadersArray;
    
}
@end

@implementation FSChatManager

@synthesize maxCount, urlRefString, chatId, currentUserId, users, delegate;

#pragma mark SINGLETON

+ (FSChatManager *) singleton {
    static dispatch_once_t pred;
    static FSChatManager *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[FSChatManager alloc] init];
    });
    return shared;
}

#pragma mark CREATE NEW CHAT

- (void) createNewChatForUsers:(NSArray *)chatters
                  withCustomId:(NSString *)customId
            andCompletionBlock:(void (^)(NSString * newChat, NSError * error))completion
{
    //NSLog(@"creating");
    NSString * chatsString = [NSString stringWithFormat:@"%@Chats/", urlRefString];
    Firebase * chatsRef = [[Firebase alloc]initWithUrl:chatsString];
    Firebase * newChatRef;
    
    if (customId) {
        newChatRef = [chatsRef childByAppendingPath:customId];
    }
    else {
        newChatRef = [chatsRef childByAutoId];
    }
    
    NSMutableDictionary * newChat = [NSMutableDictionary new];
    newChat[@"users"] = chatters;
    
    NSString * timeStamp = TimeStamp;
    NSMutableDictionary * headerDict = [NSMutableDictionary new];
    
    for (NSString * str in chatters) {
        headerDict[str] = timeStamp;
    }
    
    headerDict[kHeaderTimeStamp] = timeStamp;
    headerDict[kHeaderLastMessage] = @"";
    newChat[@"header"] = headerDict;
    
    newChat[@"createdAt"] = timeStamp;
    
    [newChatRef setValue:newChat andPriority:timeStamp withCompletionBlock:^(NSError *error, Firebase *ref) {
        if (!error) {
            NSLog(@"REF: %@", ref.name);
            
            [self addChatWithId:ref.name toUsers:chatters withCompletionBlock:completion];
        }
        else {
            completion(nil, error);
        }
    }];
}

- (void) addChatWithId:(NSString *)chat
               toUsers:(NSArray *)chatters
   withCompletionBlock:(void (^)(NSString * newChat, NSError * error))completion
{
    
    __block int count = 0;
    
    for (NSString * user in chatters) {
        NSString * user1URL = [NSString stringWithFormat:@"%@Users/%@/chats", urlRefString, user];
        Firebase * chatsRef = [[Firebase alloc]initWithUrl:user1URL];
        [[chatsRef childByAutoId] setValue:chat withCompletionBlock:^(NSError *error, Firebase *ref) {
            if (!error) {
                //NSLog(@"Added: %@ To: %@", chat, user);
                count++;
                if (count == chatters.count) {
                    //NSLog(@"\n\n\nCompleting!!! \n\n\n");
                    completion(chat, nil);
                }
            }
            else {
                completion(nil, error);
            }
        }];
    }
}

#pragma mark ADD USER

- (void) addUserId:(NSString *)userId toChatId:(NSString *)chattId withCompletionBlock:(void (^)(NSString * chatId, NSError * error))completion {
    
    NSString * headerRefURL = [NSString stringWithFormat:@"%@Chats/%@/header/", urlRefString, chattId];
    Firebase * headerRef = [[Firebase alloc]initWithUrl:headerRefURL];
    
    [headerRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
        
        if (currentData.value != [NSNull new]) {
            
            // Get Header From Value
            NSMutableDictionary * header = currentData.value;
            NSLog(@"Header");
            
            NSMutableArray * usersArr = header[@"users"];
            if (![usersArr containsObject:userId]) {
                [usersArr addObject:userId];
            }
            
            users = [NSArray arrayWithArray:usersArr];
            
            header[@"users"] = usersArr;
            
            [currentData setValue:header];
        }
        
        // Return It
        return [FTransactionResult successWithValue:currentData];
    } andCompletionBlock:^(NSError *error, BOOL committed, FDataSnapshot *snapshot) {
        if (!error) {
            // Done!
            [self addChatWithId:chattId toUsers:@[userId] withCompletionBlock:completion];
        }
    } withLocalEvents:NO];
    
}

#pragma mark HEADERS QUERY

- (void) getChatHeadersWithCompletionBlock:(void (^)(NSArray * messages, NSError * error))completion {
    
    // Step 1 - Get User's Chats
    NSString * userChatsURL = [NSString stringWithFormat:@"%@Users/%@/chats/",urlRefString, currentUserId];
    Firebase * userChatsRef = [[Firebase alloc]initWithUrl:userChatsURL];
    
    [userChatsRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        if (snapshot.value != [NSNull new]) {
            
            // Parse Chats Into Array
            NSArray * keys = [snapshot.value allKeys];
            NSMutableArray * chatsArray = [NSMutableArray new];
            for (NSString * key in keys) {
                [chatsArray addObject:snapshot.value[key]];
            }
            
            // An Array Of Chat Ids
            [self getHeadersForChatsArray:chatsArray withCompletionBlock:completion];
            
        }
        else {
            // No Chats
            completion(nil, nil);
        }
    } withCancelBlock:^(NSError *error) {
        completion(nil, error);
    }];
}

- (void) getHeadersForChatsArray:(NSArray *)chatsArray withCompletionBlock:(void (^)(NSArray * messages, NSError * error))completion {
    
    NSLog(@"GETTING HEADERS");
    
    if (!receivedHeadersArray) receivedHeadersArray = [NSMutableArray new];
    
    for (NSString * chatIdString in chatsArray) {
        
        NSString * headerString = [NSString stringWithFormat:@"%@Chats/%@/header/",urlRefString, chatIdString];
        Firebase * headerSnap = [[Firebase alloc]initWithUrl:headerString];
        
        [headerSnap observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
            NSLog(@"Got Header: %@", snapshot.value);
            if (snapshot.value != [NSNull new]) {
                
                
                [receivedHeadersArray addObject:snapshot.value];
                if (receivedHeadersArray.count == chatsArray.count) {
                    completion(receivedHeadersArray, nil);
                    receivedHeadersArray = nil;
                }
            }
        }];
    }
}
     
#pragma mark START CHAT SESSION

/*
 Currently passing the completion block around, perhaps better to store it as a property?
 
 @property (nonatomic, copy) void (^simpleCompletionBlock)(void);
 */

// Step 1 - Get Users
- (void) loadChatSessionWithCompletionBlock:(void (^)(NSArray * messages, NSError * error))completion {
    
    if (!urlRefString || !chatId) {
        NSLog(@"\n\n ** CHAT MANAGER NOT STARTING -- SET urlRefString & chatId BEFORE STARTING SESSION! ** \n\n");
        return;
    }
    
    // Create UserRef
    NSString * userURL = [NSString stringWithFormat:@"%@/Chats/%@/users", urlRefString, chatId];
    Firebase *userRef = [[Firebase alloc] initWithUrl:userURL];
    // Get Users Snapshot
    [userRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        
        // Does Snapshot Exist?
        if (snapshot.value != [NSNull new]) {
            
            // Save Users
            users = snapshot.value;
            
            // Next Step --> Count
            [self getCountWithCompletionBlock:completion];
        }
        
        // No User Array!
        else {
            
            // Return Arrow
            NSError * err = [NSError errorWithDomain:@"Unable To Retrieve Users -- Chats Must Have Array of User Id's to Properly Manag Chat" code:1 userInfo:nil];
            completion(nil, err);
        }
    } withCancelBlock:^(NSError *error) {
        
        // Cancelled Here, Report Error
        completion(nil, error);
    }];
    
}

// Step 2 - Count Messages
- (void) getCountWithCompletionBlock:(void (^)(NSArray * messages, NSError * error))completion {
    NSLog(@"GETTING COUNT!!");
    
    // Set Max
    maxMessageCount = 50;
    if (maxCount) maxMessageCount = maxCount.intValue;
    
    // Create Count Ref If Necessary (will reference later)
    if (!countRef) {
        NSString * countURL = [NSString stringWithFormat:@"%@/Chats/%@/count", urlRefString, chatId];
        countRef = [[Firebase alloc] initWithUrl:countURL];
    }
    
    // Find Current Count
    [countRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        
        NSLog(@"GOT COUNT: %@", snapshot.value);
        if (snapshot.value != [NSNull null]) {
            
            // Received Count, Get Messages
            [self getMessagesForCount:[snapshot.value intValue] withCompletion:completion];
        }
        else {
            // No Messages Exist -- Send Block
            completion(nil, nil);
        }
    } withCancelBlock:^(NSError *error) {
        
        // Return Error
        NSError * err = [NSError errorWithDomain:@"Failed To Get Count" code:0 userInfo:nil];
        completion(nil, err);
    }];
}

// Step 3 - Get Messages & Start Incoming Monitor
- (void) getMessagesForCount:(int)count withCompletion:(void (^)(NSArray *, NSError *))completion {
    
    // Set Total Messages To Max If Greater Than
    if (count > maxMessageCount) count = maxMessageCount;
    
    // Create Messages Ref If Necessary
    if (!messagesRef) {
        NSString * messagesURL = [NSString stringWithFormat:@"%@Chats/%@/messages/", urlRefString, chatId];
        messagesRef = [[Firebase alloc] initWithUrl:messagesURL];
    }
    
    // Set Query
    FQuery * firebaseQ = [messagesRef queryLimitedToNumberOfChildren:maxMessageCount];
    
    // Prepare Array
    if (!receivedMessagesArray) receivedMessagesArray = [NSMutableArray new];
    
    // Run Query
    queryHandle = [firebaseQ observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {

        // Received Value -- > Add To Array
        if (snapshot.value != [NSNull new]) [receivedMessagesArray addObject:snapshot.value];
        
        // Finished Query -- > All Objects Retrieved
        if (count == receivedMessagesArray.count) {
            
            // Remove Query
            [messagesRef removeObserverWithHandle:queryHandle];
            
            // Run Completion -- Send Retrieved Array
            completion(receivedMessagesArray, nil);
            
            // Monitor Any Messages Since Last Retrieved Message
            [self monitorIncomingMessagesWithPriority:[NSString stringWithFormat:@"%f", [snapshot.priority doubleValue] + 1]];
            
            // Clear Array, No Longer Needed
            receivedMessagesArray = nil;
        }
    }];
}

// Step 4 - Monitor Incoming Messages
- (void) monitorIncomingMessagesWithPriority:(NSString *)priority {
    
    // Create Messages Ref If Necessary -- SHOULD ALREADY EXIST!
    if (!messagesRef) {
        NSString * messagesURL = [NSString stringWithFormat:@"%@Chats/%@/messages/", urlRefString, chatId];
        messagesRef = [[Firebase alloc] initWithUrl:messagesURL];
    }
    
    NSLog(@"querying priority: %@", priority);
    
    // Set Query For Messages After Last Message Of Query Or Newer
    FQuery * nowOrNewerQuery = [messagesRef queryStartingAtPriority:priority];
    
    // Set Handle To Remove Later
    messageMonitorHandle = [nowOrNewerQuery observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
        
        // If there's data, send it to delegate!
        if (snapshot.value != [NSNull new]) {
            NSLog(@"notifying delegate: %@", snapshot.value);
            // Notify Delegate
            [delegate newMessageReceived:snapshot.value];
        }
        
    }];
}

// Load Older Messages

/*
 Get next 50 from priority of oldest message we already have
 */

#pragma mark END CHAT SESSION

- (void) endChatSessionWithCompletionBlock:(void (^)(void))completion {
    [messagesRef removeObserverWithHandle:messageMonitorHandle];
    [messagesRef removeAllObservers];
    messagesRef = nil;
    
    [chatHeaderRef removeAllObservers];
    chatHeaderRef = nil;
    
    [countRef removeAllObservers];
    countRef = nil;
    
    completion();
}

#pragma mark ADD MESSAGE TO CHAT

- (void) sendNewMessage:(NSString *)content {
    
    NSLog(@"sending new message chat Id: %@", chatId);
    
    // Get Users
    NSString * fromUserId = currentUserId;
    NSString * toUserId = users[0];
    
    if ([fromUserId isEqualToString:toUserId]) toUserId = users[1];
    
    for (NSString * user in users) {
        if (![user isEqualToString:fromUserId]) {
            toUserId = user;
            break;
        }
    }
    
    /*
     Firebase Priority Doesn't Calculate Decimals in priorities, Multiply By 1000 To Expose Milliseconds and have more accurate priorities!
     */
    
    // Create Timestamp -- Milliseconds required for accuracy!
    NSString * timestamp = [NSString stringWithFormat:@"%f",[[NSDate new] timeIntervalSince1970] * 1000];
    
    // Construct Message
    NSMutableDictionary * message = [NSMutableDictionary new];
    if (content) message[kMessageContent] = content;
    if (timestamp) message[kMessageTimestamp] = timestamp;
    if (fromUserId) message[kMessageSentTo] = fromUserId;
    if (toUserId) message[kMessageSentFrom] = toUserId;
    
    message[kMessageChatId] = chatId;
    
    // Create Message Ref If Necessary
    if (!messagesRef) {
        NSString * messageRefString = [NSString stringWithFormat:@"%@%@%@%@%@", urlRefString, @"Chats/", chatId, @"/", @"messages/"];
        messagesRef = [[Firebase alloc]initWithUrl:messageRefString];
    }
    
    // Send It Off -- Priority In Milliseconds
    [[messagesRef childByAutoId]setValue:message andPriority:timestamp withCompletionBlock:^(NSError *error, Firebase *ref) {
        if (!error) {
            //NSLog(@"success");
        }
        else {
            NSLog(@"Message Save Error: %@", error);
        }
    }];
    
    // Update Header
    [self updateHeaderWithMessage:message];
    
    // Update Count
    [self updateCount];
    
    // Notify User
    if (toUserId) [self notifyUserWithId:toUserId ofMessage:message];
}

- (void) updateHeaderWithMessage:(NSMutableDictionary *)message {

    // Create Header Ref If Necessary
    if (!chatHeaderRef) {
        
        NSLog(@"no chat header");
        NSLog(@"ChatId: %@ Ref: %@", chatId, urlRefString);
        NSString * headerRefString = [NSString stringWithFormat:@"%@%@%@%@%@", urlRefString, @"Chats/", chatId, @"/", @"header/"];
        chatHeaderRef = [[Firebase alloc]initWithUrl:headerRefString];
    }
    
    // Update Header If It's Newer Via Transaction
    [chatHeaderRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
        
        NSLog(@"transacting");
        
        // Declare Header Variable
        NSMutableDictionary * header;
        
        NSLog(@"got data: %@", currentData.value);
        // Does Header Exist?
        if (currentData.value != [NSNull new]) {
            
            // Get Header From Value
            header = currentData.value;
            NSLog(@"Header");
            // Set Last Time Our Current User Performed An Action
            if (currentUserId) {
                
                // Add Message Timestamp If Newer
                if ([message[kMessageTimestamp] doubleValue] > [header[currentUserId] doubleValue]) {
                    
                    // Set Last Time
                    header[currentUserId] = message[kMessageTimestamp];
                    
                }
            }
                
            // Is Our Message Newer?
            if ([message[kMessageTimestamp] doubleValue] > [header[kHeaderTimeStamp] doubleValue]) {
                
                // Update Message
                header[kHeaderTimeStamp] = message[kMessageTimestamp]; // Last Updated
                header[kHeaderLastMessage] = message[kMessageContent];
            }
        }
        
        // No Header, Create One
        else {
            NSLog(@"constructing header");
            // Construct Header
            header = [NSMutableDictionary new];
            
            NSLog(@"message: %@", message);
            
            // Set Last Updated
            header[kHeaderTimeStamp] = message[kMessageTimestamp];
            header[kHeaderLastMessage] = message[kMessageContent];
            
            // Last Seen
            header[currentUserId] = message[kMessageTimestamp];
        }
        
        // Set Our Updated Header
        [currentData setValue:header];
        
        // Return It
        return [FTransactionResult successWithValue:currentData];
    } andCompletionBlock:^(NSError *error, BOOL committed, FDataSnapshot *snapshot) {
        if (!error) {
            // Done!
        }
    } withLocalEvents:NO];
}

- (void) updateCount {
    
    // Create Count Ref If Necessary
    if (!countRef) {
        NSString * countURL = [NSString stringWithFormat:@"%@Chats/%@/count", urlRefString, chatId];
        countRef = [[Firebase alloc] initWithUrl:countURL];
    }
    
    // Update New Count
    [countRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
        
        // Check If Exists
        if (currentData.value != [NSNull new]) {
            
            // + 1
            [currentData setValue:[NSNumber numberWithInt:(1 + [currentData.value intValue])]];
        }
        
        // Doesn't Exist
        else {
            
            // Set New Value - 1
            [currentData setValue:[NSNumber numberWithInt:1]];
        }
        
        // Return It!
        return [FTransactionResult successWithValue:currentData];
    }];
}

- (void) notifyUserWithId:(NSString *)userToNotifyId ofMessage:(NSDictionary *)message {
    
    NSLog(@"prepping notification");
    
    // NOTIFICATIONS
    FSChannelManager * channelManager = [FSChannelManager singleton];
    [channelManager sendAlertToUserId:userToNotifyId
                        withAlertType:@"newMessage"
                              andData:message
                       withCompletion:^(NSError *error) {
        //
        NSLog(@"alert sent!");
    }];
    
}

@end
