FireSuite
=========

#ALPHA

A set of classes to monitor connections / presence, p2p chats, and a user to user alerts stream on the Firebase backend.

## Chat QuickStart

### Step 1: Declare FSChatManagerDelegateProtocol

In ViewController.h

```ObjC
#import "FireSuite.h"

@interface ViewController : UIViewController <FSChatManagerDelegate>

@end
```

In ViewController.m

```ObjC
#pragma mark CHAT MANAGER DELEGATE

- (void) newMessageReceived:(NSMutableDictionary *)newMessage {
    NSLog(@"Received New Message: %@", newMessage);
    
    if ([newMessage[kMessageContent] isEqualToString:@"Hello World!"]) {
        NSLog(@"Hello Firebase!");
    }
}

- (void) chatSessionLoadDidFinishWithResponse:(NSDictionary *)response {
    NSDictionary * header = response[kResponseHeader];
    NSArray * retrievedMessages = response[kResponseMessages];
    
    NSLog(@"Retrieved Header: %@ andMessages: %@", header, retrievedMessages);
}

- (void) chatSessionLoadDidFailWithError:(NSError*)error {
    NSLog(@"loadDidFail: %@", error);
}

- (void) sendMessage:(NSDictionary *)message didFailWithError:(NSError *)error {
     NSLog(@"sendMessage: %@ DidFail: %@", message, error);
}
```
### Step 2: Initialize FireSuite

```ObjC
[FireSuite setFirebaseURL:@"https://someFirebase.firebaseIO.com/"];
[FireSuite setCurrentUserId:@"currentUserId"];
```

### Step 3: Create Chat

```ObjC
FSChatManager * chatManager = [FireSuite chatManager];
chatManager.delegate = self;
    
// Create New Chat For @"currentUserId", @"anotherUserId"
// Set CustomId to nil for AutoId
[chatManager createNewChatForUsers:@[@"currentUserId", @"anotherUserId"]
                      withCustomId:nil
                andCompletionBlock:^(NSString *newChatId, NSError *error) {
                     if (!error) {
            
                        // ------- LOAD NEW CHAT SESSION ------ //
                        [chatManager loadChatSessionWithChatId:newChatId andNumberOfRecentMessages:50];
                        // Start New Chat Session w/ the new chat Id and Max Number Of Recent Messages To Retrieve from the server
                        
                     }
               }];
               
```

### Step 4: Send A Message:

```ObjC
[[FireSuite chatManager] sendNewMessage:@"Hello World!"];
```

You'll receive the callback through delegate:
```
// On Success
- (void) newMessageReceived:(NSDictionary *)newMessage;

// On Error
- (void) sendMessage:(NSDictionary *)message didFailWithError:(NSError *)error;
