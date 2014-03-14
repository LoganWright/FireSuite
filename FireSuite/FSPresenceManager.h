//
//  FSPresenceManager.h
//  ChatPhantom
//
//  Created by Logan Wright on 3/9/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Firebase/Firebase.h>

/*!
 Manage Firebase User Presence System -- Requires goOffline | goOnline In App Delegate!
 */
@interface FSPresenceManager : NSObject

#pragma mark SINGLETON -- MANAGER

+ (FSPresenceManager *) singleton;

@property (strong, nonatomic) NSString * urlRefString;

@property (strong, nonatomic) NSString * currentUserId;

@property (strong, nonatomic) id someProperty;

#pragma mark START PRESENCE MANAGER
/*!
 Call this somewhere in your code to begin the presence manager.  It's ok, but not advisable to call this multiple times.
 */
- (void) startPresenceManager;

#pragma mark CONNECTION STATUS OBSERVERS -- REGISTER FOR NOTIFICATIONS

// Register
- (void) registerConnectionStatusObserver:(NSObject *)observer withSelector:(SEL)selector;

// Remove
- (void) removeAllConnectionStatusObservers;
- (void) removeConnectionStatusObserver:(NSObject *)observer;
- (void) removeAllConnectionStatusObserversExcept:(NSObject *)observer;


#pragma mark USER STATUS OBSERVERS -- REGISTER FOR NOTIFICATIONS

// Register
- (void) registerUserStatusObserver:(NSObject *)observer withSelector:(SEL)selector forUserId:(NSString *)userIdToObserve;

// Remove
- (void) removeAllUserStatusObservers;
- (void) removeUserStatusObserversForObject:(NSObject *)observerToRemove;
- (void) removeUserStatusObserversForUserId:(NSString *)userIdToRemove;
- (void) removeStatusObserverForObject:(NSObject *)observerToRemove andUserId:(NSString *)userIdToRemove;
- (void) removeAllUserStatusObserverObjectsExcept:(NSObject *)observerToKeep;
- (void) removeAllUserStatusObserversExceptForUserId:(NSString *)userIdToKeep;
- (void) removeAllUserStatusObserversExceptForObserverObject:(NSObject *)observerToKeep andUserId:(NSString *)userIdToKeep;

@end
