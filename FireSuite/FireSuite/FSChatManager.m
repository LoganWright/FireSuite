//
//  FSChatManager.m
//
//  Created by Logan Wright on 3/8/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "FSChatManager.h"
#import "FSChannelManager.h"

// Extern Keys
NSString *const kResponseMessages = @"kResponseMessages";
NSString *const kResponseHeader = @"kResponseHeader";

// Message Keys
static NSString * kMessageSentTo = @"sentTo";
static NSString * kMessageSentBy = @"sentBy";
static NSString * kMessageContent = @"content";
static NSString * kMessageTimestamp = @"timestamp";
static NSString * kMessageHasViewed = @"hasViewed";
static NSString * kMessageChatId = @"chatId";

// Header Keys
static NSString * kHeaderLastMessage = @"lastMessage";
static NSString * kHeaderTimeStamp = @"timestamp";
static NSString * kHeaderCreatedAt = @"createdAt";

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
            andCompletionBlock:(void (^)(NSString * newChat, NSError * error))completion {
    NSString * chatsString = [NSString stringWithFormat:@"%@Chats/", _urlRefString];
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

- (void) addChatWithId:(NSString *)chatId
               toUsers:(NSArray *)users
   withCompletionBlock:(void (^)(NSString * newChat, NSError * error))completion {
    __block int count = 0;
    
    for (NSString * user in users) {
        NSString * user1URL = [NSString stringWithFormat:@"%@Users/%@/chats", _urlRefString, user];
        Firebase * chatsRef = [[Firebase alloc]initWithUrl:user1URL];
        [[chatsRef childByAutoId] setValue:chatId withCompletionBlock:^(NSError *error, Firebase *ref) {
            if (!error) {
                count++;
                if (count == users.count) {
                    completion(chatId, nil);
                }
            }
            else {
                completion(nil, error);
            }
        }];
    }
}

#pragma mark ADD USER TO CHAT

- (void) addUserId:(NSString *)userId
          toChatId:(NSString *)chatId
withCompletionBlock:(void (^)(NSString * chatId, NSError * error))completion {
    
    // Get Header
    NSString * headerRefURL = [NSString stringWithFormat:@"%@Chats/%@/header/", _urlRefString, chatId];
    Firebase * headerRef = [[Firebase alloc]initWithUrl:headerRefURL];
    
    // Transact
    [headerRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
        
        if (currentData.value != [NSNull new]) {
            
            // Get Header From Value
            NSMutableDictionary * header = currentData.value;
            NSLog(@"Header");
            
            NSMutableArray * usersArr = header[@"users"];
            if (![usersArr containsObject:userId]) {
                [usersArr addObject:userId];
            }
            
            _users = [NSArray arrayWithArray:usersArr];
            
            header[@"users"] = usersArr;
            
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

- (void) getChatHeadersWithCompletionBlock:(void (^)(NSArray * headers, NSError * error))completion {

    NSString * userChatsURL = [NSString stringWithFormat:@"%@Users/%@/chats/",_urlRefString, _currentUserId];
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
            [self getHeadersForArray:chatsArray withCompletionBlock:completion];
            
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
    
    for (NSString * chatIdString in headers) {
        
        NSString * headerString = [NSString stringWithFormat:@"%@Chats/%@/header/",_urlRefString, chatIdString];
        Firebase * headerSnap = [[Firebase alloc]initWithUrl:headerString];
        
        [headerSnap observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
            if (snapshot.value != [NSNull new]) {
                [_receivedHeadersArray addObject:snapshot.value];
                if (_receivedHeadersArray.count == headers.count) {
                    completion(_receivedHeadersArray, nil);
                    _receivedHeadersArray = nil;
                }
            }
        }];
    }
}
     
#pragma mark START CHAT SESSION

- (void) loadChatSessionWithChatId:(NSString *)chatId andNumberOfRecentMessages:(int)numberOfMessages {
    
    if (_messagesRef) {
        NSLog(@"FSChatManager: ** End Chat Session Before Starting A New One! ** ");
        NSError * error = [NSError errorWithDomain:@"** End Chat Session Before Starting A New One! **" code:808 userInfo:nil];
        [_delegate chatSessionLoadDidFailWithError:error];
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
    NSString * headerString = [NSString stringWithFormat:@"%@Chats/%@/header/",_urlRefString, _chatId];
    Firebase * headerSnap = [[Firebase alloc]initWithUrl:headerString];
    
    [headerSnap observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        if (snapshot.value != [NSNull new]) {
            _responseHeader = snapshot.value;
            
            // Next Step --> Users
            [self getUsers];
        }
        else {
            NSError * error = [NSError errorWithDomain:@"Unable To Retrieve Chat Header" code:202 userInfo:nil];
            [_delegate chatSessionLoadDidFailWithError:error];
        }
    }];
}

// Step 2 - Get Users
- (void) getUsers {
    // Create UserRef
    NSString * userURL = [NSString stringWithFormat:@"%@/Chats/%@/users", _urlRefString, _chatId];
    Firebase *userRef = [[Firebase alloc] initWithUrl:userURL];
    // Get Users Snapshot
    [userRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        
        // Does Snapshot Exist?
        if (snapshot.value != [NSNull new]) {
            
            // Save Users
            _users = snapshot.value;
            
            // Next Step --> Count
            [self getCount];
        }
        
        // No User Array!
        else {
            
            // Return Arrow
            NSError * err = [NSError errorWithDomain:@"Unable To Retrieve Users -- Chats Must Have Array of 2 User Id's to Properly Manage Chat" code:1 userInfo:nil];
            [_delegate chatSessionLoadDidFailWithError:err];
        }
    } withCancelBlock:^(NSError *error) {
        
        // Cancelled Here, Report Error
        [_delegate chatSessionLoadDidFailWithError:error];
    }];
}

// Step 3 - Count Messages
- (void) getCount {
    
    // Create Count Ref If Necessary (will reference later)
    if (!_countRef) {
        NSString * countURL = [NSString stringWithFormat:@"%@/Chats/%@/count", _urlRefString, _chatId];
        _countRef = [[Firebase alloc] initWithUrl:countURL];
    }
    
    // Find Current Count
    [_countRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        
        if (snapshot.value != [NSNull null]) {
            
            // Received Count, Get Messages
            [self getMessagesForCount:[snapshot.value intValue]];
        }
        else {
            // No Messages Exist -- Send Block
            NSMutableDictionary * response = [NSMutableDictionary new];
            response[kResponseHeader] = _responseHeader;
            response[kResponseMessages] = [NSNull new];
            [_delegate chatSessionLoadDidFinishWithResponse:response];
        }
    } withCancelBlock:^(NSError *error) {
        
        // Return Error
        NSError * err = [NSError errorWithDomain:@"Failed To Get Count" code:0 userInfo:nil];
        //completion(nil, err);
        [_delegate chatSessionLoadDidFailWithError:err];
    }];
}

// Step 4 - Get Messages & Start Incoming Monitor
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
    
    // Run Query
    queryHandle = [firebaseQ observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {

        // Received Value -- > Add To Array
        if (snapshot.value != [NSNull new]) [_receivedMessagesArray addObject:snapshot.value];
        
        // Finished Query -- > All Objects Retrieved
        if (count == _receivedMessagesArray.count) {
            
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

// Step 5 - Monitor Incoming Messages
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
    
    // Get our timestamp
    NSString * timestamp = TimeStamp;
    
    // Create Header Ref If Necessary
    if (!_chatHeaderRef) {
        NSString * headerRefString = [NSString stringWithFormat:@"%@%@%@%@%@", _urlRefString, @"Chats/", _chatId, @"/", @"header/"];
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
        else {
            NSLog(@"FSChatManager: Can't Update Header -- Doesn't Exist");
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

#pragma mark ADD MESSAGE TO CHAT

- (void) sendNewMessage:(NSString *)content {
    
    // Get Users
    NSString * sentById = _currentUserId;
    
    // Sent to other
    NSString * sentToId = _users[0];
    if ([sentById isEqualToString:sentToId]) sentToId = _users[1];
    
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
        NSString * messageRefString = [NSString stringWithFormat:@"%@%@%@%@%@", _urlRefString, @"Chats/", _chatId, @"/", @"messages/"];
        _messagesRef = [[Firebase alloc]initWithUrl:messageRefString];
    }
    
    // Send It Off -- Priority In Milliseconds
    [[_messagesRef childByAutoId]setValue:message andPriority:timestamp withCompletionBlock:^(NSError *error, Firebase *ref) {
        if (!error) {
            
            // ---- Message Sent! Update Everything Else ---- //
            
            // Update Header
            [self updateHeaderWithMessage:message];
            
            // Update Count
            [self updateCount];
            
            // Notify User
            if (sentToId) [self notifyUserWithId:sentToId ofMessage:message];
        }
        else {
            [_delegate sendMessageDidFailWithError:error];
        }
    }];
    
}

- (void) updateHeaderWithMessage:(NSMutableDictionary *)message {

    // Create Header Ref If Necessary
    if (!_chatHeaderRef) {
        NSString * headerRefString = [NSString stringWithFormat:@"%@%@%@%@%@", _urlRefString, @"Chats/", _chatId, @"/", @"header/"];
        _chatHeaderRef = [[Firebase alloc]initWithUrl:headerRefString];
    }
    
    // Update Header If It's Newer Via Transaction
    [_chatHeaderRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
        
        // Declare Header Variable
        NSMutableDictionary * header;
        
        // Does Header Exist?
        if (currentData.value != [NSNull new]) {
            
            // Get Header From Value
            header = currentData.value;
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
                header[kHeaderLastMessage] = message[kMessageContent];
            }
        }
        
        // No Header, Create One
        else {
            // Construct Header
            header = [NSMutableDictionary new];
            
            // Set Last Updated
            header[kHeaderTimeStamp] = message[kMessageTimestamp];
            header[kHeaderLastMessage] = message[kMessageContent];
            
            // Last Seen
            header[_currentUserId] = message[kMessageTimestamp];
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
    if (!_countRef) {
        NSString * countURL = [NSString stringWithFormat:@"%@Chats/%@/count", _urlRefString, _chatId];
        _countRef = [[Firebase alloc] initWithUrl:countURL];
    }
    
    // Update New Count
    [_countRef runTransactionBlock:^FTransactionResult *(FMutableData *currentData) {
        
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

#pragma mark NOTIFY OPPONENT OF NEW MESSAGE

- (void) notifyUserWithId:(NSString *)userToNotifyId ofMessage:(NSDictionary *)message {
    
    // Update Opponent via Alert Channel
    FSChannelManager * channelManager = [FSChannelManager singleton];
    [channelManager sendAlertToUserId:userToNotifyId
                        withAlertType:kAlertTypeNewMessage
                              andData:message
                       withCompletion:nil]; // Possibly some error detection here
    
}

@end
