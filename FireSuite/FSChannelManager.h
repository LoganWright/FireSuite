//
//  FSChannelManager.h
//  ChatPhantom
//
//  Created by Logan Wright on 3/12/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Firebase/Firebase.h>

#define TimeStamp [NSString stringWithFormat:@"%f",[[NSDate new] timeIntervalSince1970] * 1000]

FOUNDATION_EXPORT NSString *const kAlertType;
FOUNDATION_EXPORT NSString *const kAlertData;
FOUNDATION_EXPORT NSString *const kAlertTimestamp;

/*!
 Used To Send And Receive Messages On User Channels
 */
@interface FSChannelManager : NSObject

+ (FSChannelManager *) singleton;

@property (strong, nonatomic) NSString * urlRefString;
@property (strong, nonatomic) NSString * currentUserId;

- (void) sendAlertToUserId:(NSString *)userId
             withAlertType:(NSString *)alertType
                   andData:(id)data
            withCompletion:(void (^)(NSError *))completion;

- (void) registerUserAlertsObserver:(NSObject *)observer withSelector:(SEL)selector;

@end
