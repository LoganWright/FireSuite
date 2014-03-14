//
//  FSChannelManager.m
//
//  Created by Logan Wright on 3/12/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

NSString *const kAlertType = @"kAlertType";
NSString *const kAlertData = @"kAlertData";
NSString *const kAlertTimestamp = @"kAlertTimestamp";
#import "FSChannelManager.h"

@interface FSChannelManager ()
{
    Firebase * alertsRef;
    
    NSMutableArray * alertsObservers;
}
@end

@implementation FSChannelManager

@synthesize urlRefString, currentUserId;

+ (FSChannelManager *) singleton {
    static dispatch_once_t pred;
    static FSChannelManager *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[FSChannelManager alloc] init];
    });
    return shared;
}

- (void) sendAlertToUserId:(NSString *)userId
             withAlertType:(NSString *)alertType
                   andData:(id)data
            withCompletion:(void (^)(NSError *))completion
{
    NSString * alertsRefString = [NSString stringWithFormat:@"%@Users/%@/alerts/", urlRefString, userId];
    Firebase * sender = [[Firebase alloc]initWithUrl:alertsRefString];
    
    NSMutableDictionary * alertt = [NSMutableDictionary new];
    alertt[kAlertType] = alertType;
    alertt[kAlertData] = data;
    
    NSString * timeStamp = TimeStamp;
    alertt[kAlertTimestamp] = timeStamp;
    [[sender childByAutoId] setValue:alertt andPriority:timeStamp withCompletionBlock:^(NSError *error, Firebase *ref) {
        
        completion(error);
        
    }];
}

#pragma mark INCOMING ALERTS MONITOR

- (void) startIncomingAlertsMonitor {
    
    // If ConnectionMonitor Isn't Already Monitoring, Start Monitoring
    if (!alertsRef) {
        
        // Prep ConnectionRefString
        NSString * refString = [NSString stringWithFormat:@"%@Users/%@/alerts/", urlRefString, currentUserId];
        
        // Load ConnectionMonitor
        alertsRef = [[Firebase alloc] initWithUrl:refString];
        
        // Begin Observing
        [alertsRef observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot) {
            
            // Notify Observers Of Alert
            if (snapshot.value != [NSNull new]) [self notifyAlertsObservers:snapshot.value];
            
            [snapshot.ref removeValue];
            
        }];
    }
    else {
        NSLog(@"AlertsManager: Already Monitoring Alerts!");
    }
}

// Broadcast Connection Status
- (void) notifyAlertsObservers:(NSDictionary *)alert {
    
    // See If Any Observers Exist
    if (alertsObservers) {
        
        // Notify All Observers
        for (NSDictionary * observer in alertsObservers) {
            
            // Parse Observer Object
            NSObject * ob = observer[@"observerObject"];
            SEL selector = [observer[@"selector"] pointerValue];
            
            // Double Check That Selector Exists
            if ([ob respondsToSelector:selector]) {
                
                IMP imp = [ob methodForSelector:selector];
                void (*func)(id, SEL, NSDictionary *) = (void *)imp;
                func(ob, selector, alert);
                
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

- (void) endAlertsMonitorWithCompletionBlock:(void (^)(void))completion {
    [alertsRef removeAllObservers];
    alertsRef = nil;
    
    [alertsObservers removeAllObjects];
    alertsObservers = nil;
    completion();
}

#pragma mark CONNECTION STATUS OBSERVERS

- (void) registerUserAlertsObserver:(NSObject *)observer withSelector:(SEL)selector {
    
    // Start Incoming Alerts Monitor If Necessary
    if (!alertsRef) [self startIncomingAlertsMonitor];
    
    // Create Connection Status Observers Pool If Necessary
    if (!alertsObservers) alertsObservers = [NSMutableArray new];
    
    // Check Registration
    if (![self isAlertObserverAlreadyRegistered:observer]) {
        
        // Generate New Observer
        NSMutableDictionary * newObserver = [NSMutableDictionary new];
        newObserver[@"observerObject"] = observer;
        newObserver[@"selector"] = [NSValue valueWithPointer:selector];
        [alertsObservers addObject:newObserver];
    }
    else {
        // Observer Already Exists
        NSLog(@"\n\n **** 3:AlertsManager: Attempt to add connectionStatusObserver that already exists **** \n\n");
    }
}

- (void) removeAllAlertsObservers {
    if (alertsObservers) {
        [alertsObservers removeAllObjects];
        alertsObservers = nil;
    }
}

- (void) removeAlertStatusObserver:(NSObject *)observer {
    if ([self isAlertObserverAlreadyRegistered:observer]) {
        [alertsObservers removeObject:observer];
    }
}

- (void) removeAllAlertStatusObserversExcept:(NSObject *)observer {
    if (alertsObservers) {
        if ([self isAlertObserverAlreadyRegistered:observer]) {
            NSMutableDictionary * observerToSave;
            for (NSMutableDictionary * dict in alertsObservers) {
                if (dict[@"observerObject"] == observer) {
                    observerToSave = dict;
                    break;
                }
            }
            [alertsObservers removeAllObjects];
            if (observerToSave) [alertsObservers addObject:observerToSave];
        }
        else {
            NSLog(@"\n\n **** AlertsManager: Attempt to RemoveAllConnectionStatusObserversExcept: - Observer Hasn't Been Created **** \n\n");
        }
    }
    else {
        NSLog(@"\n\n **** AlertsManager: Attempt to RemoveAllConnectionStatusObserversExcept: - No Observers Exist **** \n\n");
    }
}

// Instance Level
- (BOOL) isAlertObserverAlreadyRegistered:(NSObject *)object {
    
    for (NSMutableDictionary * dic in alertsObservers) {
        if (dic[@"observerObject"] == object) {
            return YES;
        }
    }
    
    return NO;
    
}

@end
