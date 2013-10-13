//
//  AFNetworkURLConnection.h
//  CoreNetworking
//
//  Created by Keith Duncan on 22/01/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AFNetworkURLConnection : NSObject

/*!
	\brief
	Designated initialiser
 */
- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate;

/*!
	\brief
	A connection must be scheduled in at least one environment to function.
 */
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

/*!
	\brief
	A connection must be scheduled in at least one environment to function.
 */
- (void)scheduleInQueue:(dispatch_queue_t)queue;

/*!
	\brief
	Issue the request
 */
- (void)start;

@end
