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
	The source must be scheduled in at least one run loop to function.
 */
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

/*!
	\brief
	Creates a dispatch source internally.
	
	\param queue
	A layer can only be scheduled in a single queue at a time, to unschedule it pass NULL.
 */
- (void)scheduleInQueue:(dispatch_queue_t)queue;

/*!
	\brief
	
 */
- (void)start;

@end
