//
//  AFNetworkSchedulerProxy.h
//  CoreNetworking
//
//  Created by Keith Duncan on 10/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AFNetworkSchedulable <NSObject>

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue;

#endif

@end

/*!
	\brief
	Remember a scheduling environment and apply it to future objects
 */
@interface AFNetworkSchedulerProxy : NSProxy <AFNetworkSchedulable> {
 @private
	NSLock *_invocationsLock;
	NSMutableSet *_invocations;
}

/*!
	\brief
	Designated initialiser.
 */
- (id)init;

/*!
	\brief
	Replay scheduler invocations against the `networkLayer`
 */
- (void)scheduleNetworkLayer:(id <AFNetworkSchedulable>)networkLayer;

@end
