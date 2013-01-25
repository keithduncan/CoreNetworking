//
//  AFNetworkPortMapper.h
//  CoreNetworking
//
//  Created by Keith Duncan on 16/01/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Types.h"

@class AFNetworkSchedule;
@class AFNetworkPortMapper;

@protocol AFNetworkPortMapperDelegate <NSObject>

- (void)portMapper:(AFNetworkPortMapper *)portMapper didReceiveError:(NSError *)error;

- (void)portMapper:(AFNetworkPortMapper *)portMapper didMapExternalAddress:(NSData *)externalAddress;

@end

@interface AFNetworkPortMapper : NSObject

- (id)initWithSocketSignature:(AFNetworkSocketSignature const)socketSignature localAddress:(NSData *)localAddress suggestedExternalAddress:(NSData *)suggestedExternalAddress;

@property (assign, nonatomic) id <AFNetworkPortMapperDelegate> delegate;

/*
 
 */

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

- (void)scheduleInQueue:(dispatch_queue_t)queue;

/*
 
 */

- (void)start;

- (void)invalidate;

@end
