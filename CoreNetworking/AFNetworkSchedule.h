//
//  AFNetworkEnvironment.h
//  CoreNetworking
//
//  Created by Keith Duncan on 05/01/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

/*!
	\brief
	Schedule environment for run loop and dispatch
 */
@interface AFNetworkSchedule : NSObject {
 @public
	NSRunLoop *_runLoop;
	NSString *_runLoopMode;
	
	void *_dispatchQueue;
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

- (void)scheduleInQueue:(dispatch_queue_t)queue;

@end
