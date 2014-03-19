//
//  FSPresenceManager.m
//
//  Created by Logan Wright on 3/9/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import "FSPresenceManager.h"

@interface FSPresenceManager ()

// Current User's Connection To Firebase
@property (strong, nonatomic) Firebase * connectionMonitor;
// Connection Observers To Notify
@property (strong, nonatomic) NSMutableArray * connectionStatusObservers;

// Other User's Connections To Firebase
@property (strong, nonatomic) Firebase * userStatusMonitor;
// User Status Observers To Notify
@property (strong, nonatomic) NSMutableArray * userStatusObservers;

@end

@implementation FSPresenceManager

#pragma mark SINGLETON

+ (FSPresenceManager *) singleton {
    static dispatch_once_t pred;
    static FSPresenceManager *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[FSPresenceManager alloc] init];
    });
    return shared;
}

#pragma mark START CONNECTION MONITOR

- (void) startPresenceManager {
    
    // If ConnectionMonitor Isn't Already Monitoring, Start Monitoring
    if (!_connectionMonitor) {
        
        // Prep ConnectionRefString
        NSString * refString = [NSString stringWithFormat:@"%@.info/connected", _urlRefString];
        
        // Load ConnectionMonitor
        _connectionMonitor = [[Firebase alloc] initWithUrl:refString];
        
        // Begin Observing
        [_connectionMonitor observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
            if([snapshot.value boolValue]) {
                
                // Connection Established! (or I've reconnected after a loss of connection)
                
                // Get ConnectionsRef
                Firebase * con = [[Firebase alloc]initWithUrl:[NSString stringWithFormat:@"%@Users/%@/connections/", _urlRefString, _currentUserId]];
                
                // Create New Connection For This Device
                Firebase * newConnection = [con childByAutoId];
                
                // Set New Connection To Timestamp
                [newConnection setValue:[NSString stringWithFormat:@"%f",[[NSDate new] timeIntervalSince1970]]];
                
                // Set Disconnect To Remove Device;
                [newConnection onDisconnectRemoveValue];
                
                // Set Last Online Timestamp
                Firebase * lastOnlineRef = [[Firebase alloc]initWithUrl:[NSString stringWithFormat:@"%@Users/%@/lastOnline/", _urlRefString, _currentUserId]];
                
                // Set Last Online To Timestamp
                [lastOnlineRef onDisconnectSetValue:[NSString stringWithFormat:@"%f",[[NSDate new] timeIntervalSince1970]]];
            }
            
            // Notify Observers Of Connection Status Change -- Regardless Of Direction
            if (snapshot.value != [NSNull new]) [self notifyConnectionStatusObservers:[snapshot.value boolValue]];
            
        }];
    }
    else {
        NSLog(@"PresenceManager: Already Monitoring Connection!");
    }
}
// Broadcast Connection Status
- (void) notifyConnectionStatusObservers:(BOOL)isConnected {
    
    //NSLog(@"PresenceManager: Notifying ConnectionStatusObservers isOnline: %@", isConnected ? @"YES" : @"NO");
    
    // See If Any Observers Exist
    if (_connectionStatusObservers) {
        
        // Notify All Observers
        for (NSDictionary * observer in _connectionStatusObservers) {
            
            // Parse Observer Object
            NSObject * ob = observer[@"observerObject"];
            SEL selector = [observer[@"selector"] pointerValue];
            
            // Double Check That Selector Exists
            if ([ob respondsToSelector:selector]) {
                
                IMP imp = [ob methodForSelector:selector];
                void (*func)(id, SEL, BOOL) = (void *)imp;
                func(ob, selector, isConnected);
                
            }
            else {
                NSLog(@"\n\n **** Presence Manager: Attempt To Notify Connection Status Observer: %@ failed because selector did not exist **** \n\n", observer[@"observerObject"]);
            }
            
            /*
             //SEL selector = NSSelectorFromString(@"processRegion:ofView:");
             IMP imp = [ob methodForSelector:selector];
             void (*func)(id, SEL, NSString *) = (void *)imp;
             func(ob, selector, @"Hello World!");
             */
            
            /*
             IMP imp = [ob methodForSelector:selector];
             void (*func)(id, SEL, BOOL) = (void *)imp;
             func(ob, selector, YES);
             */
            
            
            /* Without arguments
             SEL selector = NSSelectorFromString(@"someMethod");
             IMP imp = [_controller methodForSelector:selector];
             void (*func)(id, SEL) = (void *)imp;
             func(_controller, selector);
             */
            
            /* with arguments
             SEL selector = NSSelectorFromString(@"processRegion:ofView:");
             IMP imp = [_controller methodForSelector:selector];
             CGRect (*func)(id, SEL, CGRect, UIView *) = (void *)imp;
             CGRect result = func(_controller, selector, someRect, someView);
             */
            
        }
    }
}

#pragma mark SET CONNECTION STATUS OBSERVERS

- (void) registerConnectionStatusObserver:(NSObject *)observer
                             withSelector:(SEL)selector {
    
    if (!_connectionMonitor) {
        [self startPresenceManager];
    }
    
    NSMethodSignature * sig = [observer methodSignatureForSelector:selector];
    
    if ([sig numberOfArguments] != 3) {
        // Why 3? -- "The hidden arguments self (of type id) and _cmd (of type SEL) are at indices 0 and 1; method-specific arguments begin at index 2." -- total count 3 means one arg
        NSLog(@"\n\n**** 1:PresenceManager: Connection Status Observer Selector Must Take 1 Argument And That Argument Must Be Of Type: BOOL ****\n\n");
        return;
    }
    
    const char * arg = [sig getArgumentTypeAtIndex:2];
    const char * arbooli = @encode(BOOL);
    
    // strcmp(str1, str2)
    // 0 if same
    // A value greater than zero indicates that the first character that does not match has a greater value in str1 than in str2;
    // And a value less than zero indicates the opposite.
    int stringCompare = strcmp(arg, arbooli);
    
    /* Option 1 - ASSERT
     NSString * errorAssertString = @"***** Connection Status Observer Selector Must Take 1 Argument And That Argument Must Be BOOL *****";
     NSAssert((0 == stringCompare && [sig numberOfArguments] == 3), errorAssertString);
     // Why 3? -- "The hidden arguments self (of type id) and _cmd (of type SEL) are at indices 0 and 1; method-specific arguments begin at index 2." -- total count 3 means one arg
     */
    //NSLog(@"string compare: %i", stringCompare);
    
    /* Option 2 - WARN */
    if (stringCompare != 0) {
        // Why 3? -- "The hidden arguments self (of type id) and _cmd (of type SEL) are at indices 0 and 1; method-specific arguments begin at index 2." -- total count 3 means one arg
        NSLog(@"\n\n**** 2:PresenceManager: Connection Status Observer Selector Must Take 1 Argument And That Argument Must Be Of Type: BOOL ****\n\n");
        return;
    }
    
    // Create Connection Status Observers Pool If Necessary
    if (!_connectionStatusObservers) _connectionStatusObservers = [NSMutableArray new];
    
    // Check Registration
    if (![self isConnectionStatusObserverAlreadyRegistered:observer]) {
        
        // Generate New Observer
        NSMutableDictionary * newObserver = [NSMutableDictionary new];
        newObserver[@"observerObject"] = observer;
        newObserver[@"selector"] = [NSValue valueWithPointer:selector];
        [_connectionStatusObservers addObject:newObserver];
    }
    else {
        // Observer Already Exists
        NSLog(@"\n\n **** 3:PresenceManager: Attempt to add connectionStatusObserver that already exists **** \n\n");
    }
    
    //NSAssert(0 == strcmp(@encode(BOOL), [sig getArgumentTypeAtIndex:2]),
    //       @"Selector must take a BOOL as its sole argument.");
    // NSLog(@"%s",[sig getArgumentTypeAtIndex:2]);
    //NSAssert(0 == strcmp(@encode(id), [sig getArgumentTypeAtIndex:2]),
    //       @"Selector must take a NSString as its sole argument.");
    
}

#pragma mark REMOVE CONNECTION STATUS OBSERVERS

- (void) removeAllConnectionStatusObservers {
    if (_connectionStatusObservers) {
        [_connectionStatusObservers removeAllObjects];
        _connectionStatusObservers = nil;
    }
}

- (void) removeConnectionStatusObserver:(NSObject *)observer {
    if ([self isConnectionStatusObserverAlreadyRegistered:observer]) {
        [_connectionStatusObservers removeObject:observer];
    }
}

- (void) removeAllConnectionStatusObserversExcept:(NSObject *)observer {
    if (_connectionStatusObservers) {
        if ([self isConnectionStatusObserverAlreadyRegistered:observer]) {
            NSMutableDictionary * observerToSave;
            for (NSMutableDictionary * dict in _connectionStatusObservers) {
                if (dict[@"observerObject"] == observer) {
                    observerToSave = dict;
                    break;
                }
            }
            [_connectionStatusObservers removeAllObjects];
            if (observerToSave) [_connectionStatusObservers addObject:observerToSave];
        }
        else {
            NSLog(@"\n\n **** PresenceManager: Attempt to RemoveAllConnectionStatusObserversExcept: - Observer Hasn't Been Created **** \n\n");
        }
    }
    else {
        NSLog(@"\n\n **** PresenceManager: Attempt to RemoveAllConnectionStatusObserversExcept: - No Observers Exist **** \n\n");
    }
}

// Instance Level
- (BOOL) isConnectionStatusObserverAlreadyRegistered:(NSObject *)object {
    
    for (NSMutableDictionary * dic in _connectionStatusObservers) {
        if (dic[@"observerObject"] == object) {
            return YES;
        }
    }
    
    return NO;
    
}

#pragma mark SET USER STATUS OBSERVERS

- (void) registerUserStatusObserver:(NSObject *)observer
                       withSelector:(SEL)selector
                          forUserId:(NSString *)userIdToObserve {
    
    //--> GoodSelector = userStatusDidUpdateWithId:(NSString *)userId andStatus:(BOOL)isOnline;
    
    // Verify Selector
    NSMethodSignature * sig = [observer methodSignatureForSelector:selector];
    
    // Check For 2 Arguments
    if ([sig numberOfArguments] != 4) {
        // Why 4? -- "The hidden arguments self (of type id) and _cmd (of type SEL) are at indices 0 and 1; method-specific arguments begin at index 2." -- total count 4 means two args
        NSLog(@"\n\n 1:**** PresenceManager: User Status Observer Selector Must Take 2 Arguments - (1st = NSString, 2nd = BOOL)  ****\n\n");
        return;
    }
    
    // Get Argument Chars
    const char * arg1 = [sig getArgumentTypeAtIndex:2];
    const char * arg2 = [sig getArgumentTypeAtIndex:3];
    
    const char * obChar = @encode(id);
    const char * boolChar = @encode(BOOL);
    
    // strcmp(str1, str2)
    // 0 if same
    // A value greater than zero indicates that the first character that does not match has a greater value in str1 than in str2;
    // And a value less than zero indicates the opposite.
    
    // Ob 1 -> Object (should be NSString)
    int firstArgStringCompare = strcmp(arg1, obChar);
    
    // Ob 2 -> BOOL
    int secondArgStringCompare = strcmp(arg2, boolChar);
    
    // Argument Types Check
    if (firstArgStringCompare != 0 || secondArgStringCompare != 0) {
        NSLog(@"\n\n**** 2:PresenceManager: User Status Observer Selector Must Take 2 Arguments - (1st = NSString, 2nd = BOOL)  ****\n\n");
        return;
    }
    
    // At this point, the selector has passed verification!
    
    // Generate New Observer
    NSMutableDictionary * newObserver = [NSMutableDictionary new];
    newObserver[@"observerObject"] = observer;
    newObserver[@"selector"] = [NSValue valueWithPointer:selector];
    newObserver[@"userId"] = userIdToObserve;
    
    // Check Registration
    if (![self doesUserStatusObserverAlreadyExist:newObserver]) {
        
        // Is New User Status Observer
        [self createMonitorForNewUserStatusObserver:newObserver];
        
    }
    else {
        
        // User Status Observer Already Exists
        NSLog(@"\n\n 3:PresenceManager: Attempt to add userStatusObserver that already exists \n\n");
    }
    
}
// Broadcast User Status
- (void) createMonitorForNewUserStatusObserver:(NSMutableDictionary *)newObserver {
    
    // Create UserStatusMonitor If Necessary
    if (!_userStatusMonitor) {
        NSString * userStatusMonitorString = [NSString stringWithFormat:@"%@%@", _urlRefString, @"Users/"];
        //NSLog(@"STRING: %@", userStatusMonitorString);
        _userStatusMonitor = [[Firebase alloc]initWithUrl:userStatusMonitorString];
        //NSLog(@"userStatusMonitor: %@", userStatusMonitor);
    }
    
    // Generate Child For User
    Firebase * childRef = [_userStatusMonitor childByAppendingPath:[NSString stringWithFormat:@"%@/connections/", newObserver[@"userId"]]];
    
    // Monitor This User's Connection Status
    FirebaseHandle userHandle = [childRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        
        NSLog(@"Received User Statusupdate: %@", snapshot.value);
        
        // Set Offline
        BOOL isOnline = NO;
        
        // Snapshot Array Of Connected Devices
        if (snapshot.value != [NSNull new]) {
            
            // User Is Online
            isOnline = YES;
        }
        
        // Parse Out Observer Dict
        NSObject * ob = newObserver[@"observerObject"];
        SEL selector = [newObserver[@"selector"] pointerValue];
        
        // Double Check That Selector Exists
        if ([ob respondsToSelector:selector]) {
            
            // Parse And Execute Selector
            IMP imp = [ob methodForSelector:selector];
            void (*func)(id, SEL, NSString*, BOOL) = (void *)imp;
            func(ob, selector, newObserver[@"userId"], isOnline);
            
        }
        else {
            
            // Notify Of Error
            NSLog(@"\n\n **** Presence Manager: Attempt To Notify UserStatusObserver: %@ failed because selector did not exist **** \n\n", newObserver[@"observerObject"]);
        }
    }];
    
    // Add Handle To Stop Later
    newObserver[@"firebaseHandle"] = [NSNumber numberWithInt:userHandle];
    
    // Create UserStatusObservers Pool If Necessary
    if (!_userStatusObservers) _userStatusObservers = [NSMutableArray new];
    
    // Add Observer To Our Collection
    [_userStatusObservers addObject:newObserver];
    
    // NSLog(@"UserStatusObservers: %@", userStatusObservers);
    
}

#pragma mark REMOVE USER STATUS OBSERVERS

- (void) removeAllUserStatusObservers {
    if (_userStatusObservers) {
        for (NSMutableDictionary * observerOb in _userStatusObservers) {
            [_userStatusMonitor removeObserverWithHandle:[observerOb[@"firebaseHandle"]intValue]];
        }
        _userStatusObservers = nil;
    }
}

- (void) removeUserStatusObserversForObject:(NSObject *)observerToRemove {
    if (_userStatusObservers) {
        NSMutableArray * keepers = [NSMutableArray new];
        for (NSMutableDictionary * observerOb in _userStatusObservers) {
            if (observerOb[@"observerObject"] == observerToRemove) {
                [_userStatusMonitor removeObserverWithHandle:[observerOb[@"firebaseHandle"]intValue]];
            }
            else {
                [keepers addObject:observerOb];
            }
        }
        _userStatusObservers = keepers;
    }
}

- (void) removeUserStatusObserversForUserId:(NSString *)userIdToRemove {
    if (_userStatusObservers) {
        NSMutableArray * keepers = [NSMutableArray new];
        for (NSMutableDictionary * observerOb in _userStatusObservers) {
            if ([observerOb[@"userId"] isEqualToString:userIdToRemove]) {
                [_userStatusMonitor removeObserverWithHandle:[observerOb[@"firebaseHandle"]intValue]];
            }
            else {
                [keepers addObject:observerOb];
            }
        }
        _userStatusObservers = keepers;
    }
}

- (void) removeStatusObserverForObject:(NSObject *)observerToRemove
                             andUserId:(NSString *)userIdToRemove {
    if (_userStatusObservers) {
        NSMutableArray * keepers = [NSMutableArray new];
        for (NSMutableDictionary * observerOb in _userStatusObservers) {
            if (observerOb[@"observerObject"] == observerToRemove && [observerOb[@"userId"]isEqualToString:userIdToRemove]) {
                [_userStatusMonitor removeObserverWithHandle:[observerOb[@"firebaseHandle"]intValue]];
            }
            else {
                [keepers addObject:observerOb];
            }
        }
        _userStatusObservers = keepers;
    }
}

- (void) removeAllUserStatusObserverObjectsExcept:(NSObject *)observerToKeep {
    if (_userStatusObservers) {
        NSMutableArray * keepers = [NSMutableArray new];
        for (NSMutableDictionary * observerOb in _userStatusObservers) {
            if (observerOb[@"observerObject"] == observerToKeep) {
                [keepers addObject:observerOb];
            }
            else {
                [_userStatusMonitor removeObserverWithHandle:[observerOb[@"firebaseHandle"]intValue]];
            }
        }
        _userStatusObservers = keepers;
    }
}

- (void) removeAllUserStatusObserversExceptForUserId:(NSString *)userIdToKeep {
    if (_userStatusObservers) {
        NSMutableArray * keepers = [NSMutableArray new];
        for (NSMutableDictionary * observerOb in _userStatusObservers) {
            if ([observerOb[@"userId"]isEqualToString:userIdToKeep]) {
                [keepers addObject:observerOb];
            }
            else {
                [_userStatusMonitor removeObserverWithHandle:[observerOb[@"firebaseHandle"]intValue]];
            }
        }
        _userStatusObservers = keepers;
    }
}

- (void) removeAllUserStatusObserversExceptForObserverObject:(NSObject *)observerToKeep
                                                   andUserId:(NSString *)userIdToKeep {
    if (_userStatusObservers) {
        NSMutableArray * keepers = [NSMutableArray new];
        for (NSMutableDictionary * observerOb in _userStatusObservers) {
            if (observerOb[@"observerObject"] == observerToKeep && [observerOb[@"userId"]isEqualToString:userIdToKeep]) {
                [keepers addObject:observerOb];
            }
            else {
                [_userStatusMonitor removeObserverWithHandle:[observerOb[@"firebaseHandle"]intValue]];
            }
        }
        _userStatusObservers = keepers;
    }
}

// Instance Checker
- (BOOL) doesUserStatusObserverAlreadyExist:(NSMutableDictionary *)userStatusObserver {
    
    for (NSMutableDictionary * dic in _userStatusObservers) {
        if (dic[@"observerObject"] == userStatusObserver[@"observerObject"] && [dic[@"userId"] isEqualToString:userStatusObserver[@"userId"]]) {
            return YES;
        }
    }
    
    return NO;
    
}

#pragma mark END PRESENCE MONITOR

- (void) stopPresenceMonitorWithCompletion:(void(^)(void))completion {
    [self removeAllUserStatusObservers];
    [self removeAllConnectionStatusObservers];
    [_connectionMonitor removeAllObservers];
    [_userStatusMonitor removeAllObservers];
    completion();
}

@end
