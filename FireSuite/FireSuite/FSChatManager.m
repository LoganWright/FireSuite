//
//  FSChatManager.m
//
//  Created by Logan Wright on 3/8/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "FSChatManager.h"
#import "FSChannelManager.h"


#pragma mark KEYS

// Extern Keys
NSString *const kResponseMessages = @"kResponseMessages";
NSString *const kResponseHeader = @"kResponseHeader";

// Error Keys
NSString *const kFSChatManagerErrorDomain = @"kFSChatManagerErrorDomain";
NSString *const kErrorFailedToGetHeader = @"Failed To Get Chat Header";
NSString *const kErrorAlreadyInUse = @"Chat Manager Is Already In Use";

// Chat Keys
NSString *const kChatHeader= @"header";
NSString *const kChatMessages = @"messages";
NSString *const kChatCreatedAt = @"createdAt";
NSString *const kChatUsers = @"users";

// Header Keys
NSString *const kHeaderLastMessage = @"lastMessage";
NSString *const kHeaderTimeStamp = @"timestamp";
NSString *const kHeaderCreatedAt = @"createdAt";
NSString *const kHeaderUsers = @"users";
NSString *const kHeaderMessageCount = @"messageCount";

// Message Keys
NSString *const kMessageSentTo = @"sentTo";
NSString *const kMessageSentBy = @"sentBy";
NSString *const kMessageContent = @"content";
NSString *const kMessageTimestamp = @"timestamp";
NSString *const kMessageHasViewed = @"hasViewed";
NSString *const kMessageChatId = @"chatId";



@interface FSChatManager ()

{
    // For Finding Observers
    FirebaseHandle queryHandle;
    FirebaseHandle messageMonitorHandle;
    
    // For Response
    int maxMessageCount;
    
    // Headers
    int headerCount;
}

// For Header Query
@property (strong, nonatomic) NSMutableArray * receivedHeadersArray;

// Initial Load Response
@property (strong, nonatomic) NSMutableArray * receivedMessagesArray;
@property (strong, nonatomic) NSDictionary * responseHeader;

// Our Firebase Refs
@property (strong, nonatomic) Firebase * countRef;
@property (strong, nonatomic) Firebase * messagesRef;
@property (strong, nonatomic) Firebase * chatHeaderRef;

// Users for current chat
@property (strong, nonatomic) NSArray * users;

@end

@implementation FSChatManager

#pragma mark SINGLETON

+ (instancetype) singleton {
    static dispatch_once_t pred;
    static FSChatManager *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[FSChatManager alloc] init];
    });
    return shared;
}

#pragma mark CREATE NEW CHAT

- (void) createNewChatForUsers:(NSArray *)users
                  withCustomId:(NSString *)customId
            andCompletionBlock:(void (^)(NSString * newChatId, NSError * error))completion {
    NSString * chatsString = [NSString stringWithFormat:@"%@Chats/", _urlRefString];
    Firebase * chatsRef = [[Firebase alloc]initWithUrl:chatsString];
    Firebase * newChatRef;
    
    if (customId) {
        newChatRef = [chatsRef childByAppendingPath:customId];
    }
    else {
        newChatRef = [chatsRef childByAutoId];
    }
    
    /*
    NSMutableDictionary * newChat = [NSMutableDictionary new];
    if (users.count > 0) newChat[kChatUsers] = users;
    
    NSString * timeStamp = TimeStamp;
    NSMutableDictionary * headerDict = [NSMutableDictionary new];
    
    for (NSString * str in users) {
        headerDict[str] = timeStamp;
    }
    */
    
    
    NSString * timeStamp = TimeStamp;
    NSMutableDictionary * headerDict = [NSMutableDictionary new];
    if (users.count > 0) headerDict[kHeaderUsers] = users;
    for (NSString * str in users) {
        headerDict[str] = timeStamp;
    }
    // Set Header
    headerDict[kHeaderTimeStamp] = timeStamp; // will vary ...
    headerDict[kHeaderLastMessage] = @"";
    headerDict[kHeaderCreatedAt] = timeStamp; // will remain fixed
    headerDict[kHeaderMessageCount] = [NSNumber numberWithInt:0];
    
    // Set Header To Chat
    NSMutableDictionary * newChat = [NSMutableDictionary new];
    newChat[kChatHeader] = headerDict;
    
    // Unnecessary
    // newChat[kChatCreatedAt] = timeStamp;
    //
    
    [newChatRef setValue:newChat andPriority:timeStamp withCompletionBlock:^(NSError *error, Firebase *ref) {
        if (!error) {
            if (users) {
                [self addChatWithId:ref.name toUsers:users withCompletionBlock:completion];
            }
            else {
                completion(ref.name, nil);
            }
        }
        else {
            completion(nil, error);
        }
    }];
}

- (void) addChatWithId:(NSString *)chatId
               toUsers:(NSArray *)users
   withCompletionBlock:(void (^)(NSString * newChat, NSError * error))completion {
    __block int count = 0;
    
    if (users.count > 0) {
        for (NSString * user in users) {
            NSString * user1URL = [NSString stringWithFormat:@"%@Users/%@/chats/", _urlRefString, user];
            Firebase * chatsRef = [[Firebase alloc]initWithUrl:user1URL];
            
            [chatsRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
                NSMutableArray * chatsArray;
                
                if (currentData.value != [NSNull new]) {
                    chatsArray = currentData.value;
                    if (![chatsArray containsObject:chatId]) {
                        [chatsArray addObject:chatId];
                    }
                }
                else {
                    chatsArray = [NSMutableArray new];
                    [chatsArray addObject:chatId];
                }
                
                [currentData setValue:chatsArray];
                return [FTransactionResult successWithValue:currentData];
            } andCompletionBlock:^(NSError *error, BOOL committed, FDataSnapshot *snapshot) {
                
                count++;
                if (!error) {
                    if (count == users.count) {
                        completion(chatId, nil);
                    }
                }
                else {
                    completion(nil, error);
                }
                
            } withLocalEvents:NO];
            
        }
    }
    else {
        completion(chatId, nil);
    }
}

#pragma mark ADD USER TO CHAT

- (void) addUserId:(NSString *)userId
          toChatId:(NSString *)chatId
withCompletionBlock:(void (^)(NSString * chatId, NSError * error))completion {
    
    // Get Header
    NSString * headerRefURL = [NSString stringWithFormat:@"%@Chats/%@/header/", _urlRefString, chatId];
    Firebase * headerRef = [[Firebase alloc]initWithUrl:headerRefURL];
    
    NSString * timestamp = TimeStamp;
    
    // Transact
    [headerRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
        
        if (currentData.value != [NSNull new]) {
            
            // Get Header From Value
            NSMutableDictionary * header = currentData.value;
            
            NSMutableArray * usersArr = header[kHeaderUsers];
            if (![usersArr containsObject:userId]) {
                [usersArr addObject:userId];
            }
            
            _users = [NSArray arrayWithArray:usersArr];
            
            if (usersArr) header[@"users"] = usersArr;
            if (timestamp) header[userId] = timestamp;
            [currentData setValue:header];
        }
        
        // Return It
        return [FTransactionResult successWithValue:currentData];
    } andCompletionBlock:^(NSError *error, BOOL committed, FDataSnapshot *snapshot) {
        if (!error) {
            
            // Done!
            [self addChatWithId:chatId toUsers:@[userId] withCompletionBlock:completion];
        }
    } withLocalEvents:NO];
    
}

#pragma mark HEADERS QUERY

- (void) getChatHeadersForUserId:(NSString *)userId
             WithCompletionBlock:(void (^)(NSArray * headers, NSError * error))completion {

    NSString * userChatsURL = [NSString stringWithFormat:@"%@Users/%@/chats/",_urlRefString, userId];
    Firebase * userChatsRef = [[Firebase alloc]initWithUrl:userChatsURL];
    
    [userChatsRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        if (snapshot.value != [NSNull new]) {
            
            // An Array Of Chat Ids
            [self getHeadersForArray:snapshot.value withCompletionBlock:completion];
            
        }
        else {
            // No Chats
            completion(nil, nil);
        }
    } withCancelBlock:^(NSError *error) {
        completion(nil, error);
    }];
}

- (void) getHeadersForArray:(NSArray *)headers
        withCompletionBlock:(void (^)(NSArray * headers, NSError * error))completion {
    
    if (!_receivedHeadersArray) _receivedHeadersArray = [NSMutableArray new];
    
    __block int blockCount = 0;
    
    for (NSString * chatIdString in headers) {
        
        // Construct header ref
        NSString * headerString = [NSString stringWithFormat:@"%@Chats/%@/header/",_urlRefString, chatIdString];
        Firebase * headerSnap = [[Firebase alloc]initWithUrl:headerString];
        
        [headerSnap observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
            
            blockCount++;
            
            if (snapshot.value != [NSNull new]) {
                [_receivedHeadersArray addObject:snapshot.value];
                
            }
            else {
                NSLog(@"Chat doesn't exist: %@", chatIdString);
            }
    
            // Check if we've received everything we're expecting.
            if (blockCount == headers.count) {
                completion(_receivedHeadersArray, nil);
                _receivedHeadersArray = nil;
            }
            
        }];
    }
}
     
#pragma mark START CHAT SESSION

- (void) loadChatSessionWithChatId:(NSString *)chatId andNumberOfRecentMessages:(int)numberOfMessages {
    
    if (_messagesRef) {
        
        // -- Opt 1 - Return Error: Already In Use
        
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: NSLocalizedString(kErrorAlreadyInUse, nil),
                                   NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Chat Manager Is Already Active", nil),
                                   NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Call endChatSessionWithCompletionBlock: before loading a new chat session.", nil)
                                   };
        
        NSError * error = [NSError errorWithDomain:kFSChatManagerErrorDomain
                                              code:FSChatErrorAlreadyInUse
                                          userInfo:userInfo];
        
        [_delegate chatSessionLoadDidFailWithError:error];
        
        
        // Opt 2 - End automatically
        
        /*
        [self endChatSessionWithCompletionBlock:^(NSError *error) {
            [self loadChatSessionWithChatId:chatId andNumberOfRecentMessages:numberOfMessages];
        }];
        */
        
        return;
    }
    
    // Set Our Values
    _chatId = chatId;
    maxMessageCount = numberOfMessages;
    
    // ** Get Header ...
    [self getHeader];
    
}

// Step 1 - Get Header
- (void) getHeader {
    
    NSString * timestamp = TimeStamp;
    
    // Create Header Ref If Necessary
    if (!_chatHeaderRef) {
        NSString * headerRefString = [NSString stringWithFormat:@"%@Chats/%@/header/", _urlRefString, _chatId];
        _chatHeaderRef = [[Firebase alloc]initWithUrl:headerRefString];
    }
    
    // Update Header To Latest Timestamp for CurrentUser
    [_chatHeaderRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
        
        // Does Header Exist?
        if (currentData.value != [NSNull new]) {
            
            // Get Header From Value
            NSMutableDictionary * header = currentData.value;
            
            // Update Current User Timestamp -  Set Last Time Our Current User Performed An Action
            if (_currentUserId) {
                // Add Last Seen Timestamp If Newer
                if ([timestamp doubleValue] > [header[_currentUserId] doubleValue]) {
                    // Set Last Time
                    header[_currentUserId] = timestamp;
                }
            }
            
            // Get Our Users ...
            if (header[kHeaderUsers]) _users = header[kHeaderUsers];
            
            // Set Value To Our Updated Header
            [currentData setValue:header];
        }
        
        // Return It
        return [FTransactionResult successWithValue:currentData];
    } andCompletionBlock:^(NSError *error, BOOL committed, FDataSnapshot *snapshot) {
        
        // Continue
        if (snapshot.value != [NSNull new]) {
            
            _responseHeader = snapshot.value;
            
            if (_responseHeader[kHeaderMessageCount] && [_responseHeader[kHeaderMessageCount] intValue] > 0)
            {
                // Received Count, Get Messages
                [self getMessagesForCount:[_responseHeader[kHeaderMessageCount] intValue]];
            }
            else {
                
                // No Messages Exist -- Send Response
                NSMutableDictionary * response = [NSMutableDictionary new];
                response[kResponseHeader] = _responseHeader;
                response[kResponseMessages] = [NSNull new];
                [_delegate chatSessionLoadDidFinishWithResponse:response];
                
                // Start Monitor
                [self monitorIncomingMessagesWithPriority:_responseHeader[kHeaderTimeStamp]];
            }
        }
        else {
            // Return Error
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: NSLocalizedString(kErrorFailedToGetHeader, nil),
                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Doesn't Exist", nil),
                                       NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Chat was likely created incorrectly.", nil)
                                       };
            NSError * error = [NSError errorWithDomain:kFSChatManagerErrorDomain
                                                  code:FSChatErrorFailedToGetHeader
                                              userInfo:userInfo];
            [_delegate chatSessionLoadDidFailWithError:error];
        }
    } withLocalEvents:NO];
}

// Step 2 - Get Messages
- (void) getMessagesForCount:(int)count {
    
    // Set Total Messages To Max If Greater Than
    if (count > maxMessageCount) count = maxMessageCount;
    
    // Create Messages Ref If Necessary
    if (!_messagesRef) {
        NSString * messagesURL = [NSString stringWithFormat:@"%@Chats/%@/messages/", _urlRefString, _chatId];
        _messagesRef = [[Firebase alloc] initWithUrl:messagesURL];
    }
    
    // Set Query
    FQuery * firebaseQ = [_messagesRef queryLimitedToNumberOfChildren:count];
    
    // Prepare Array
    if (!_receivedMessagesArray) _receivedMessagesArray = [NSMutableArray new];
    
    __block int queryCount = 0;
    
    // Run Query
    queryHandle = [firebaseQ observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
        
        // Query Count - Fire regardless, messages shouldn't be nil
        queryCount++;
        
        // Received Value -- > Add To Array
        if (snapshot.value != [NSNull new]) [_receivedMessagesArray addObject:snapshot.value];
        
        // Finished Query -- > All Expected Objects Retrieved
        if (queryCount == count) {
            
            // Remove Query
            [_messagesRef removeObserverWithHandle:queryHandle];
            
            // Run Completion -- Send Response
            NSMutableDictionary * response = [NSMutableDictionary new];
            response[kResponseHeader] = _responseHeader;
            response[kResponseMessages] = _receivedMessagesArray;
            [_delegate chatSessionLoadDidFinishWithResponse:response];
            
            // Monitor Any Messages Since Last Retrieved Message
            [self monitorIncomingMessagesWithPriority:[NSString stringWithFormat:@"%f", [snapshot.priority doubleValue] + 1]];
            
            // Clear Array, No Longer Needed
            _receivedMessagesArray = nil;
        }
    }];
}

// Step 3 - Monitor Incoming Messages
- (void) monitorIncomingMessagesWithPriority:(NSString *)priority {
    
    // Create Messages Ref If Necessary -- SHOULD ALREADY EXIST!
    if (!_messagesRef) {
        NSString * messagesURL = [NSString stringWithFormat:@"%@Chats/%@/messages/", _urlRefString, _chatId];
        _messagesRef = [[Firebase alloc] initWithUrl:messagesURL];
    }
    
    // Set Query For Messages After Last Message Of Query Or Newer
    FQuery * nowOrNewerQuery = [_messagesRef queryStartingAtPriority:priority];
    
    // Set Handle To Remove Later
    messageMonitorHandle = [nowOrNewerQuery observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
        
        // If there's data, send it to delegate!
        if (snapshot.value != [NSNull new]) {
            // Notify Delegate
            [_delegate newMessageReceived:snapshot.value];
        }
        
    }];
}

#pragma mark END CHAT SESSION

- (void) endChatSessionWithCompletionBlock:(void (^)(NSError * error))completion {
    
    if (_chatId) {
        // Get our timestamp
        NSString * timestamp = TimeStamp;
        
        // Create Header Ref If Necessary
        if (!_chatHeaderRef) {
            NSString * headerRefString = [NSString stringWithFormat:@"%@Chats/%@/header/", _urlRefString, _chatId];
            _chatHeaderRef = [[Firebase alloc]initWithUrl:headerRefString];
        }
        
        // Update Header To Latest Timestamp for CurrentUser
        [_chatHeaderRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
            
            // Declare Header Variable
            NSMutableDictionary * header;
            
            // Does Header Exist?
            if (currentData.value != [NSNull new]) {
                
                // Get Header From Value
                header = currentData.value;
                
                // Set Last Time Our Current User Performed An Action
                if (_currentUserId) {
                    
                    // Add Last Seen Timestamp If Newer
                    if ([timestamp doubleValue] > [header[_currentUserId] doubleValue]) {
                        
                        // Set Last Time
                        header[_currentUserId] = timestamp;
                        
                    }
                }
                
                [currentData setValue:header];
            }
            
            // Return It
            return [FTransactionResult successWithValue:currentData];
        } andCompletionBlock:^(NSError *error, BOOL committed, FDataSnapshot *snapshot) {
            
            [_messagesRef removeObserverWithHandle:messageMonitorHandle];
            [_messagesRef removeAllObservers];
            _messagesRef = nil;
            
            [_chatHeaderRef removeAllObservers];
            _chatHeaderRef = nil;
            
            [_countRef removeAllObservers];
            _countRef = nil;
            
            _users = nil;
            _chatId = nil;
            
            [_receivedMessagesArray removeAllObjects];
            _receivedMessagesArray = nil;
            
            _responseHeader = nil;
            
            [_receivedHeadersArray removeAllObjects];
            _receivedHeadersArray = nil;
            
            completion(error);
            
        } withLocalEvents:NO];
    }
    else {
        completion(nil);
    }
}

#pragma mark ADD MESSAGE TO CHAT

- (void) sendNewMessage:(NSString *)content {
    
    // Get Users
    NSString * sentById = _currentUserId;
    
    // SentTo - Opponent
    // If more than 2, is for chat, and not directly to a user
    NSString * sentToId;
    if (_users.count == 2) {
        sentToId = _users[0];
        if ([sentById isEqualToString:sentToId]) sentToId = _users[1];
    }
    
    /*
     Firebase Priority Doesn't Calculate Decimals in priorities, Multiply By 1000 To Expose Milliseconds and have more accurate priorities!
     */
    
    // Set Timestamp so all are same.
    NSString * timestamp = TimeStamp;
    
    // Construct Message
    NSMutableDictionary * message = [NSMutableDictionary new];
    if (timestamp) message[kMessageTimestamp] = timestamp;
    if (content) message[kMessageContent] = content;
    if (sentToId) message[kMessageSentTo] = sentToId;
    if (sentById) message[kMessageSentBy] = sentById;
    if (_chatId) message[kMessageChatId] = _chatId;
    
    // Create Message Ref If Necessary
    if (!_messagesRef) {
        NSString * messageRefString = [NSString stringWithFormat:@"%@Chats/%@/messages/", _urlRefString, _chatId];
        _messagesRef = [[Firebase alloc]initWithUrl:messageRefString];
    }
    
    // Send It Off -- Priority In Milliseconds
    [[_messagesRef childByAutoId]setValue:message andPriority:timestamp withCompletionBlock:^(NSError *error, Firebase *ref) {
        if (!error) {
            
            // ---- Message Sent! Update Everything Else ---- //
            
            // Update Header
            [self updateHeaderWithMessage:message];
            
            // Notify User -- via Alerts -- add parameter, if online, else push?
            // Maybe just let developer do this
            if (sentToId) [self notifyUserWithId:sentToId ofMessage:message];
        }
        else {
            [_delegate sendMessage:message didFailWithError:error];
        }
    }];
    
}

- (void) updateHeaderWithMessage:(NSMutableDictionary *)message {

    // Create Header Ref If Necessary
    if (!_chatHeaderRef) {
        NSString * headerRefString = [NSString stringWithFormat:@"%@Chats/%@/header/", _urlRefString, _chatId];
        _chatHeaderRef = [[Firebase alloc]initWithUrl:headerRefString];
    }
    
    // Update Header If It's Newer Via Transaction
    [_chatHeaderRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
        
        // Does Header Exist?
        if (currentData.value != [NSNull new]) {
            
            // Get Header From Value
            NSMutableDictionary * header = currentData.value;
            // Set Last Time Our Current User Performed An Action
            if (_currentUserId) {
                
                // Add Message Timestamp If Newer
                if ([message[kMessageTimestamp] doubleValue] > [header[_currentUserId] doubleValue]) {
                    
                    // Set Last Time
                    header[_currentUserId] = message[kMessageTimestamp];
                    
                }
            }
                
            // Is Our Message Newer?
            if ([message[kMessageTimestamp] doubleValue] > [header[kHeaderTimeStamp] doubleValue]) {
                
                // Update Message
                header[kHeaderTimeStamp] = message[kMessageTimestamp]; // Last Updated
                header[kHeaderLastMessage] = message;
            }
            
            // Update Count
            header[kHeaderMessageCount] = [NSNumber numberWithInt:[header[kHeaderMessageCount] intValue ] + 1];
            
            // Set Our Updated Header
            [currentData setValue:header];
        }
        
        // Return It
        return [FTransactionResult successWithValue:currentData];
    } andCompletionBlock:^(NSError *error, BOOL committed, FDataSnapshot *snapshot) {
        if (!error) {
            // Done!
            // If sent properly, should be received through didReceiveMessage.
        }
    } withLocalEvents:NO];
}

#pragma mark NOTIFY OPPONENT OF NEW MESSAGE -- Might Omit ...

- (void) notifyUserWithId:(NSString *)userToNotifyId ofMessage:(NSDictionary *)message {
    
    // Update Opponent via Alert Channel
    FSChannelManager * channelManager = [FSChannelManager singleton];
    [channelManager sendAlertToUserId:userToNotifyId
                        withAlertType:kAlertTypeNewMessage
                              andData:message
                       withCompletion:nil]; // Possibly some error detection here
    
}

@end
