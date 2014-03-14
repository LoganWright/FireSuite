/*
 * Firebase iOS Client Library
 *
 * Copyright © 2013 Firebase - All Rights Reserved
 * https://www.firebase.com
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binaryform must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY FIREBASE AS IS AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL FIREBASE BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <Foundation/Foundation.h>
#import "FQuery.h"
#import "FDataSnapshot.h"
#import "FMutableData.h"
#import "FTransactionResult.h"

/**
 * A Firebase reference represents a particular location in your Firebase
 * and can be used for reading or writing data to that Firebase location.
 *
 * This class is the starting point for all Firebase operations. After you've
 * initialized it with initWithUrl: you can use it
 * to read data (ie. observeEventType:withBlock:), write data (ie. setValue:), and to create new
 * Firebase references (ie. child:).
 */
@interface Firebase : FQuery


/** @name Initializing a Firebase object */

/**
 * Initialize this Firebase reference with an absolute URL. 
 *
 * @param url The Firebase URL (ie: https://SampleChat.firebaseIO-demo.com)
 */
- (id)initWithUrl:(NSString *)url;

/** @name Getting references to children locations */

/**
 * Get a Firebase reference for the location at the specified relative path.
 * The relative path can either be a simple child name (e.g. 'fred') or a 
 * deeper slash-separated path (e.g. 'fred/name/first').
 *
 * @param pathString A relative path from this location to the desired child location.
 * @return A Firebase reference for the specified relative path.
 */
- (Firebase *) childByAppendingPath:(NSString *)pathString;


/**
 * childByAutoId generates a new child location using a unique name and returns a
 * Firebase reference to it. This is useful when the children of a Firebase
 * location represent a list of items.
 *
 * The unique name generated by childByAutoId: is prefixed with a client-generated
 * timestamp so that the resulting list will be chronologically-sorted.
 *
 * @return A Firebase reference for the generated location.
 */
- (Firebase *) childByAutoId;


/** @name Writing data */

/*!  Write data to this Firebase location.

This will overwrite any data at this location and all child locations. 
 
Data types that can be set are:

- NSString -- @"Hello World"
- NSNumber (also includes boolean) -- @YES, @43, @4.333
- NSDictionary -- @{@"key": @"value", @"nested": @{@"another": @"value"} }
- NSArray

The effect of the write will be visible immediately and the corresponding
events will be triggered. Synchronization of the data to the Firebase 
servers will also be started.
 
Passing null for the new value is equivalent to calling remove:;
all data at this location or any child location will be deleted.

Note that setValue: will remove any priority stored at this location, so if priority
is meant to be preserved, you should use setValue:andPriority: instead.


**Server Values** - Placeholder values you may write into Firebase as a value or priority
that will automatically be populated by the Firebase Server.

- kFirebaseServerValueTimestamp - The number of milliseconds since the Unix epoch

 
@param value The value to be written.
 */
- (void) setValue:(id)value;


#define kFirebaseServerValueTimestamp @{ @".sv": @"timestamp" }


/**
 * The same as setValue: with a block that gets triggered after the write operation has
 * been committed to the Firebase servers.
 *
 * @param value The value to be written.
 * @param block The block to be called after the write has been committed to the Firebase servers.
 */
- (void) setValue:(id)value withCompletionBlock:(void (^)(NSError* error, Firebase* ref))block;


/**
 * The same as setValue: with an additional priority to be attached to the data being written.
 * Priorities are used to order items.
 *
 * @param value The value to be written.
 * @param priority The priority to be attached to that data.
 */
- (void) setValue:(id)value andPriority:(id)priority;


/**
 * The same as setValue:andPriority: with a block that gets triggered after the write operation has
 * been committed to the Firebase servers.
 *
 * @param value The value to be written.
 * @param priority The priority to be attached to that data.
 * @param block The block to be called after the write has been committed to the Firebase servers.
 */
- (void) setValue:(id)value andPriority:(id)priority withCompletionBlock:(void (^)(NSError* error, Firebase* ref))block;


/**
 * Remove the data at this Firebase location. Any data at child locations will also be deleted.
 * 
 * The effect of the delete will be visible immediately and the corresponding events
 * will be triggered. Synchronization of the delete to the Firebase servers will 
 * also be started.
 *
 * remove: is equivalent to calling setValue:nil
 */
- (void) removeValue;


/**
 * The same as remove: with a block that gets triggered after the remove operation has
 * been committed to the Firebase servers.
 *
 * @param block The block to be called after the remove has been committed to the Firebase servers.
 */
- (void) removeValueWithCompletionBlock:(void (^)(NSError* error, Firebase* ref))block;

/**
 * Set a priority for the data at this Firebase location.
 * Priorities can be used to provide a custom ordering for the children at a location
 * (if no priorities are specified, the children are ordered by name).
 *
 * You cannot set a priority on an empty location. For this reason
 * setValue:andPriority: should be used when setting initial data with a specific priority
 * and setPriority: should be used when updating the priority of existing data.
 *
 * Children are sorted based on this priority using the following rules:
 *
 * Children with no priority come first.
 * Children with a number as their priority come next. They are sorted numerically by priority (small to large).
 * Children with a string as their priority come last. They are sorted lexicographically by priority.
 * Whenever two children have the same priority (including no priority), they are sorted by name. Numeric 
 * names come first (sorted numerically), followed by the remaining names (sorted lexicographically).
 * 
 * Note that priorities are parsed and ordered as IEEE 754 double-precision floating-point numbers.
 * Names are always stored as strings and are treated as numbers only when they can be parsed as a 
 * 32-bit integer
 *
 * @param priority The priority to set at the specified location.
 */
- (void) setPriority:(id)priority;


/**
 * The same as setPriority: with a block block that is called once the priority has
 * been committed to the Firebase servers.
 *
 * @param priority The priority to set at the specified location.
 * @param block The block that is triggered after the priority has been written on the servers.
 */
- (void) setPriority:(id)priority withCompletionBlock:(void (^)(NSError* error, Firebase* ref))block;

/**
 * Update changes the values of the keys specified in the dictionary without overwriting other
 * keys at this location.
 *
 * @param values A dictionary of the keys to change and their new values
 */
- (void) updateChildValues:(NSDictionary *)values;

/**
 * The same as update: with a block block that is called once the update has been committed to the 
 * Firebase servers
 *
 * @param values A dictionary of the keys to change and their new values
 * @param block The block that is triggered after the update has been written on the Firebase servers
 */
- (void) updateChildValues:(NSDictionary *)values withCompletionBlock:(void (^)(NSError* error, Firebase* ref))block;


/** @name Attaching observers to read data */

/*! observeEventType:withBlock: is used to listen for data changes at a particular location.
 
This is the primary way to read data from Firebase. Your block will be triggered
for the initial data and again whenever the data changes.
 
Use removeObserverWithHandle: to stop receiving updates.
 
Supported events types for all realtime observers are specified in FEventType as:

    typedef enum {
      FEventTypeChildAdded,    // 0, fired when a new child node is added to a location
      FEventTypeChildRemoved,  // 1, fired when a child node is removed from a location
      FEventTypeChildChanged,  // 2, fired when a child node at a location changes
      FEventTypeChildMoved,    // 3, fired when a child node moves relative to the other child nodes at a location
      FEventTypeValue          // 4, fired when any data changes at a location and, recursively, any children
    } FEventType;

@param eventType The type of event to listen for.
@param block The block that should be called with initial data and updates as a FDataSnapshot.
@return A handle used to unregister this block later using removeObserverWithHandle:
*/
- (FirebaseHandle) observeEventType:(FEventType)eventType withBlock:(void (^)(FDataSnapshot* snapshot))block;


/**
 * observeEventType:andPreviousSiblingWithBlock: is used to listen for data changes at a particular location.
 * This is the primary way to read data from Firebase. Your block will be triggered
 * for the initial data and again whenever the data changes. In addition, for FEventTypeChildAdded, FEventTypeChildMoved, and
 * FEventTypeChildChanged events, your block will be passed the name of the previous node by priority order.
 *
 * Use removeObserverWithHandle: to stop receiving updates.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates as a FDataSnapshot, as well as the previous child's name.
 * @return A handle used to unregister this block later using removeObserverWithHandle:
 */
- (FirebaseHandle) observeEventType:(FEventType)eventType andPreviousSiblingNameWithBlock:(void (^)(FDataSnapshot* snapshot, NSString* prevName))block;


/**
 * observeEventType:withBlock: is used to listen for data changes at a particular location.
 * This is the primary way to read data from Firebase. Your block will be triggered
 * for the initial data and again whenever the data changes.
 *
 * The cancelBlock will be called if you will no longer receive new events due to no longer having permission.
 *
 * Use removeObserverWithHandle: to stop receiving updates.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates as a FDataSnapshot.
 * @param cancelBlock The block that should be called if this client no longer has permission to receive these events
 * @return A handle used to unregister this block later using removeObserverWithHandle:
 */
- (FirebaseHandle) observeEventType:(FEventType)eventType withBlock:(void (^)(FDataSnapshot* snapshot))block withCancelBlock:(void (^)(NSError* error))cancelBlock;


/**
 * observeEventType:andPreviousSiblingWithBlock: is used to listen for data changes at a particular location.
 * This is the primary way to read data from Firebase. Your block will be triggered
 * for the initial data and again whenever the data changes. In addition, for FEventTypeChildAdded, FEventTypeChildMoved, and
 * FEventTypeChildChanged events, your block will be passed the name of the previous node by priority order.
 *
 * The cancelBlock will be called if you will no longer receive new events due to no longer having permission.
 *
 * Use removeObserverWithHandle: to stop receiving updates.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates as a FDataSnapshot, as well as the previous child's name.
 * @param cancelBlock The block that should be called if this client no longer has permission to receive these events
 * @return A handle used to unregister this block later using removeObserverWithHandle:
 */
- (FirebaseHandle) observeEventType:(FEventType)eventType andPreviousSiblingNameWithBlock:(void (^)(FDataSnapshot* snapshot, NSString* prevName))block withCancelBlock:(void (^)(NSError* error))cancelBlock;


/**
 * This is equivalent to observeEventType:withBlock:, except the block is immediately canceled after the initial data is returned.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates as a FDataSnapshot.
 */
- (void) observeSingleEventOfType:(FEventType)eventType withBlock:(void (^)(FDataSnapshot* snapshot))block;


/**
 * This is equivalent to observeEventType:withBlock:, except the block is immediately canceled after the initial data is returned. In addition, for FEventTypeChildAdded, FEventTypeChildMoved, and
 * FEventTypeChildChanged events, your block will be passed the name of the previous node by priority order.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates as a FDataSnapshot, as well as the previous child's name.
 */
- (void) observeSingleEventOfType:(FEventType)eventType andPreviousSiblingNameWithBlock:(void (^)(FDataSnapshot* snapshot, NSString* prevName))block;


/**
 * This is equivalent to observeEventType:withBlock:, except the block is immediately canceled after the initial data is returned.
 *
 * The cancelBlock will be called if you do not have permission to read data at this location.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates as a FDataSnapshot.
 * @param cancelBlock The block that will be called if you don't have permission to access this data
 */
- (void) observeSingleEventOfType:(FEventType)eventType withBlock:(void (^)(FDataSnapshot* snapshot))block withCancelBlock:(void (^)(NSError* error))cancelBlock;


/**
 * This is equivalent to observeEventType:withBlock:, except the block is immediately canceled after the initial data is returned. In addition, for FEventTypeChildAdded, FEventTypeChildMoved, and
 * FEventTypeChildChanged events, your block will be passed the name of the previous node by priority order.
 *
 * The cancelBlock will be called if you do not have permission to read data at this location.
 *
 * @param eventType The type of event to listen for.
 * @param block The block that should be called with initial data and updates as a FDataSnapshot, as well as the previous child's name.
 * @param cancelBlock The block that will be called if you don't have permission to access this data
 */
- (void) observeSingleEventOfType:(FEventType)eventType andPreviousSiblingNameWithBlock:(void (^)(FDataSnapshot* snapshot, NSString* prevName))block withCancelBlock:(void (^)(NSError* error))cancelBlock;

/** @name Detaching observers */

/**
 * Detach a block previously attached with observeEventType:withBlock:. 
 *
 * @param handle The handle returned by the call to observeEventType:withBlock: which we are trying to remove.
 */
- (void) removeObserverWithHandle:(FirebaseHandle)handle;


/**
 * Detach all blocks previously attached to this Firebase location with observeEventType:withBlock:
 */
- (void) removeAllObservers;

/** @name Querying and limiting */

/**
 * queryStartingAtPriority: is used to generate a reference to a limited view of the data at this location.
 * The FQuery instance returned by queryStartingAtPriority: will respond to events at nodes with a priority
 * greater than or equal to startPriority
 *
 * @param startPriority The lower bound, inclusive, for the priority of data visible to the returned FQuery
 * @return An FQuery instance, limited to data with priority greater than or equal to startPriority
 */
- (FQuery *) queryStartingAtPriority:(id)startPriority;


/**
 * queryStartingAtPriority:andChildName: is used to generate a reference to a limited view of the data at this location.
 * The FQuery instance returned by queryStartingAtPriority:andChildName will respond to events at nodes with a priority
 * greater than startPriority, or equal to startPriority and with a name greater than or equal to childName
 *
 * @param startPriority The lower bound, inclusive, for the priority of data visible to the returned FQuery
 * @param childName The lower bound, inclusive, for the name of nodes with priority equal to startPriority
 * @return An FQuery instance, limited to data with priority greater than or equal to startPriority
 */
- (FQuery *) queryStartingAtPriority:(id)startPriority andChildName:(NSString *)childName;


/**
 * queryEndingAtPriority: is used to generate a reference to a limited view of the data at this location.
 * The FQuery instance returned by queryEndingAtPriority: will respond to events at nodes with a priority
 * less than or equal to startPriority and with a name greater than or equal to childName
 *
 * @param endPriority The upper bound, inclusive, for the priority of data visible to the returned FQuery
 * @return An FQuery instance, limited to data with priority less than or equal to endPriority
 */
- (FQuery *) queryEndingAtPriority:(id)endPriority;


/**
 * queryEndingAtPriority:andChildName: is used to generate a reference to a limited view of the data at this location.
 * The FQuery instance returned by queryEndingAtPriority:andChildNAme will respond to events at nodes with a priority
 * less than endPriority, or equal to endPriority and with a name less than or equal to childName
 *
 * @param endPriority The upper bound, inclusive, for the priority of data visible to the returned FQuery
 * @param childName The upper bound, inclusive, for the name of nodes with priority equal to endPriority
 * @return An FQuery instance, limited to data with priority less than endPriority or equal to endPriority and with a name less than or equal to childName 
 */
- (FQuery *) queryEndingAtPriority:(id)endPriority andChildName:(NSString *)childName;



/**
 * queryLimitedToNumberOfChildren: is used to generate a reference to a limited view of the data at this location.
 * The FQuery instance returned by queryLimitedToNumberOfChildren: will respond to events at from at most limit child nodes
 *
 * @param limit The upper bound, inclusive, for the number of child nodes to receive events for
 * @return An FQuery instance, limited to at most limit child nodes. 
 */
- (FQuery *) queryLimitedToNumberOfChildren:(NSUInteger)limit;

/** @name Managing presence */

/**
 * Ensure the data at this location is set to the specified value when
 * the client is disconnected (due to closing the browser, navigating
 * to a new page, or network issues).
 *
 * onDisconnectSetValue: is especially useful for implementing "presence" systems,
 * where a value should be changed or cleared when a user disconnects
 * so that he appears "offline" to other users.
 *
 * @param value The value to be set after the connection is lost.
 */
- (void) onDisconnectSetValue:(id)value;


/**
 * Ensure the data at this location is set to the specified value when
 * the client is disconnected (due to closing the browser, navigating
 * to a new page, or network issues).
 *
 * The completion block will be triggered when the operation has been successfully queued up on the Firebase servers
 *
 * @param value The value to be set after the connection is lost.
 * @param block Block to be triggered when the operation has been queued up on the Firebase servers
 */
- (void) onDisconnectSetValue:(id)value withCompletionBlock:(void (^)(NSError* error, Firebase* ref))block;


/**
 * Ensure the data at this location is set to the specified value and priority when
 * the client is disconnected (due to closing the browser, navigating
 * to a new page, or network issues).
 *
 * @param value The value to be set after the connection is lost.
 * @param priority The priority to be set after the connection is lost.
 */
- (void) onDisconnectSetValue:(id)value andPriority:(id)priority;


/**
 * Ensure the data at this location is set to the specified value and priority when
 * the client is disconnected (due to closing the browser, navigating
 * to a new page, or network issues).
 *
 * The completion block will be triggered when the operation has been successfully queued up on the Firebase servers
 *
 * @param value The value to be set after the connection is lost.
 * @param priority The priority to be set after the connection is lost.
 * @param block Block to be triggered when the operation has been queued up on the Firebase servers
 */
- (void) onDisconnectSetValue:(id)value andPriority:(id)priority withCompletionBlock:(void (^)(NSError* error, Firebase* ref))block;


/**
 * Ensure the data at this location is removed when
 * the client is disconnected (due to closing the app, navigating
 * to a new page, or network issues).
 *
 * onDisconnectRemoveValue is especially useful for implementing "presence" systems.
 */
- (void) onDisconnectRemoveValue;


/**
 * Ensure the data at this location is removed when
 * the client is disconnected (due to closing the app, navigating
 * to a new page, or network issues).
 *
 * onDisconnectRemoveValueWithCompletionBlock: is especially useful for implementing "presence" systems.
 *
 * @param block Block to be triggered when the operation has been queued up on the Firebase servers
 */
- (void) onDisconnectRemoveValueWithCompletionBlock:(void (^)(NSError* error, Firebase* ref))block;



/**
 * Ensure the data has the specified child values updated when
 * the client is disconnected (due to closing the browser, navigating
 * to a new page, or network issues).
 *
 *
 * @param values A dictionary of child node names and the values to set them to after the connection is lost.
 */
- (void) onDisconnectUpdateChildValues:(NSDictionary *)values;


/**
 * Ensure the data has the specified child values updated when
 * the client is disconnected (due to closing the browser, navigating
 * to a new page, or network issues).
 *
 *
 * @param values A dictionary of child node names and the values to set them to after the connection is lost.
 * @param block A block that will be called once the operation has been queued up on the Firebase servers
 */
- (void) onDisconnectUpdateChildValues:(NSDictionary *)values withCompletionBlock:(void (^)(NSError* error, Firebase* ref))block;


/**
 * Cancel any operations that are set to run on disconnect. If you previously called onDisconnectSetValue:,
 * onDisconnectRemoveValue:, or onDisconnectUpdateChildValues:, and no longer want the values updated when the 
 * connection is lost, call cancelDisconnectOperations:
 */
- (void) cancelDisconnectOperations;


/**
 * Cancel any operations that are set to run on disconnect. If you previously called onDisconnectSetValue:,
 * onDisconnectRemoveValue:, or onDisconnectUpdateChildValues:, and no longer want the values updated when the
 * connection is lost, call cancelDisconnectOperations:
 *
 * @param block A block that will be triggered once the Firebase servers have acknowledged the cancel request.
 */
- (void) cancelDisconnectOperationsWithCompletionBlock:(void (^)(NSError* error, Firebase* ref))block;


/** @name Authenticating */

/**
 * Authenticate access to this Firebase using the provided credentials. The completion block will be called with
 * the results of the authenticated attempt, and the cancelBlock will be called if the credentials become invalid
 * at some point after authentication has succeeded.
 *
 * @param credential The Firebase authentication JWT generated by a secure code on a remote server.
 * @param block This block will be called with the results of the authentication attempt
 * @param cancelBlock This block will be called if at any time in the future the credentials become invalid
 */
- (void) authWithCredential:(NSString *)credential withCompletionBlock:(void (^) (NSError* error, id data))block withCancelBlock:(void (^)(NSError* error))cancelBlock;


/**
 * Removes any credentials associated with this Firebase
 */
- (void) unauth;

/**
 * Removes any credentials associated with this Firebase. The callback block will be triggered after this operation 
 * has been acknowledged by the Firebase servers.
 */
- (void) unauthWithCompletionBlock:(void (^)(NSError* error))block;


/** @name Manual Connection Management */

/**
 * Manually disconnect the Firebase client from the server and disable automatic reconnection.
 *
 * The Firebase client automatically maintains a persistent connection to the Firebase server, 
 * which will remain active indefinitely and reconnect when disconnected. However, the goOffline( ) 
 * and goOnline( ) methods may be used to manually control the client connection in cases where 
 * a persistent connection is undesirable.
 * 
 * While offline, the Firebase client will no longer receive data updates from the server. However, 
 * all Firebase operations performed locally will continue to immediately fire events, allowing 
 * your application to continue behaving normally. Additionally, each operation performed locally 
 * will automatically be queued and retried upon reconnection to the Firebase server.
 * 
 * To reconnect to the Firebase server and begin receiving remote events, see goOnline( ). 
 * Once the connection is reestablished, the Firebase client will transmit the appropriate data 
 * and fire the appropriate events so that your client "catches up" automatically.
 * 
 * Note: Invoking this method will impact all Firebase connections. 
 */
+ (void) goOffline;

/**
 * Manually reestablish a connection to the Firebase server and enable automatic reconnection.
 *
 * The Firebase client automatically maintains a persistent connection to the Firebase server, 
 * which will remain active indefinitely and reconnect when disconnected. However, the goOffline( ) 
 * and goOnline( ) methods may be used to manually control the client connection in cases where 
 * a persistent connection is undesirable.
 * 
 * This method should be used after invoking goOffline( ) to disable the active connection. 
 * Once reconnected, the Firebase client will automatically transmit the proper data and fire 
 * the appropriate events so that your client "catches up" automatically.
 * 
 * To disconnect from the Firebase server, see goOffline( ).
 * 
 * Note: Invoking this method will impact all Firebase connections.
 */
+ (void) goOnline;


/** @name Transactions */

/**
 * Performs an optimistic-concurrency transactional update to the data at this location. Your block will be called with an FMutableData
 * instance that contains the current data at this location. Your block should update this data to the value you
 * wish to write to this location, and then return an instance of FTransactionResult with the new data.
 *
 * If, when the operation reaches the server, it turns out that this client had stale data, your block will be run
 * again with the latest data from the server.
 *
 * When your block is run, you may decide to abort the transaction by return [FTransactionResult abort].
 *
 * @param block This block receives the current data at this location and must return an instance of FTransactionResult
 */
- (void) runTransactionBlock:(FTransactionResult* (^) (FMutableData* currentData))block;


/**
 * Performs an optimistic-concurrency transactional update to the data at this location. Your block will be called with an FMutableData
 * instance that contains the current data at this location. Your block should update this data to the value you
 * wish to write to this location, and then return an instance of FTransactionResult with the new data.
 *
 * If, when the operation reaches the server, it turns out that this client had stale data, your block will be run
 * again with the latest data from the server.
 *
 * When your block is run, you may decide to abort the transaction by return [FTransactionResult abort].
 *
 * @param block This block receives the current data at this location and must return an instance of FTransactionResult
 * @param completionBlock This block will be triggered once the transaction is complete, whether it was successful or not. It will indicate if there was an error, whether or not the data was committed, and what the current value of the data at this location is.
 */
- (void) runTransactionBlock:(FTransactionResult* (^) (FMutableData* currentData))block andCompletionBlock:(void (^) (NSError* error, BOOL committed, FDataSnapshot* snapshot))completionBlock;



/**
 * Performs an optimistic-concurrency transactional update to the data at this location. Your block will be called with an FMutableData
 * instance that contains the current data at this location. Your block should update this data to the value you
 * wish to write to this location, and then return an instance of FTransactionResult with the new data.
 *
 * If, when the operation reaches the server, it turns out that this client had stale data, your block will be run
 * again with the latest data from the server.
 *
 * When your block is run, you may decide to abort the transaction by return [FTransactionResult abort].
 *
 * Since your block may be run multiple times, this client could see several immediate states that don't exist on the server. You can suppress those immediate states until the server confirms the final state of the transaction.
 *
 * @param block This block receives the current data at this location and must return an instance of FTransactionResult
 * @param completionBlock This block will be triggered once the transaction is complete, whether it was successful or not. It will indicate if there was an error, whether or not the data was committed, and what the current value of the data at this location is.
 * @param localEvents Set this to NO to suppress events raised for intermediate states, and only get events based on the final state of the transaction.
 */
- (void) runTransactionBlock:(FTransactionResult* (^) (FMutableData* currentData))block andCompletionBlock:(void (^) (NSError* error, BOOL committed, FDataSnapshot* snapshot))completionBlock withLocalEvents:(BOOL)localEvents;


/** @name Retrieving String Representation */

/**
 * Gets the absolute URL of this Firebase location. 
 *
 * @return The absolute URL of the referenced Firebase location.
 */
- (NSString *) description;

/** @name Properties */

/**
 * Get a Firebase reference for the parent location.
 * If this instance refers to the root of your Firebase, it has no parent,
 * and therefore parent( ) will return null.
 *
 * @return A Firebase reference for the parent location.
 */
@property (strong, readonly, nonatomic) Firebase* parent;


/**
 * Get a Firebase reference for the root location
 *
 * @return a new Firebase reference to root location.
 */
@property (strong, readonly, nonatomic) Firebase* root;


/**
 * Gets last token in a Firebase location (e.g. 'fred' in https://SampleChat.firebaseIO-demo.com/users/fred)
 *
 * @return The name of the location this reference points to.
 */
@property (strong, readonly, nonatomic) NSString* name;

/** @name Global configuration and settings */

/** Set the default dispatch queue for event blocks.
*
* @param queue The queue to set as the default for running blocks for all Firebase event types.
*/
+ (void) setDispatchQueue:(dispatch_queue_t)queue;

/** Retrieve the Firebase SDK version. */
+ (NSString *) sdkVersion;

+ (void) setLoggingEnabled:(BOOL)enabled;

+ (void) setOption:(NSString*)option to:(id)value;
@end
