//
//  AFNetworkLayer.h
//  Amber
//
//  Created by Keith Duncan on 04/05/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkTransportLayer.h"

#import "CoreNetworking/AFNetwork-Types.h"

/*!
	\brief
	This is the parent class for all the network stack objects. You are unlikely
	to use it directly.
	
	\details
	This class configures a bidirectional proxying system. Unimplemented methods
	are forwarded to `lowerLayer`, and the delegate accessor returns a proxy
	that forwards messages up the delegate chain.

	CFHostRef and CFNetServiceRef are both first class citizens in
	CoreNetworking, and you can easily bring a stack online using either (you
	should also consider NSURL/CFURL as a stand in for CFHostRef).
	
	CoreNetworking layers are NOT automatically scheduled in the current run
	loop on creation.

	Two means of scheduling are available; run loop based and dispatch_queue_t
	based. You must schedule the layer appropriately to receive callbacks.

	Scheduling a layer in both a run loop and a queue is unsupported, results
	are undefined.
 */
@interface AFNetworkLayer : NSObject {
 @private
	AFNetworkLayer *_lowerLayer;
	id _delegate;
	
	NSMutableDictionary *_userInfo;
}

/*!
	\brief
	Chains the layer classes.
 */
+ (Class)lowerLayerClass;

/*!
	\brief
	Designated initialiser.
 */
- (id)initWithLowerLayer:(id <AFNetworkTransportLayer>)layer;

/*!
	\brief
	Outbound initialiser.
	
	\details
	You can provide either a host + transport details, or an
	<AFNetServiceCommon> compilant object.

	If you provide a host, the details are captured and the host copied. If you
	provide an <AFNetServiceCommon> compliant object it will be used to create a
	CFNetService internally.
	
	The default implementation creates a lower-layer using `+lowerLayerClass`
	and calls the same initialiser on the new object.
 */
- (AFNetworkLayer *)initWithTransportSignature:(AFNetworkSignature)signature;

/*!
	\brief
	Data should be passed onto the lowerLayer for further processing. This might
	be a tunnel inside another connection layer, a proxy or a direct connection.
 */
- (AFNetworkLayer *)lowerLayer;

/*!
	\brief
	When accessing this property, you will not recieve the same object you
	passed in, this method returns a transparent proxy that allows a caller to
	forward messages up the delegate stack.
 */
@property (assign, nonatomic) id delegate;

/*!
	\brief
	User info lookup checks all layers.
 */
- (id)userInfoValueForKey:(id <NSCopying>)key;

/*!
	\brief
	Sets the value in the receiver's userInfo.
 */
- (void)setUserInfoValue:(id)value forKey:(id <NSCopying>)key;

/*
	Scheduling
	
	These methods do nothing by default as the abstract superclass has nothing
	to schedule.
 */

/*!
	\brief
	A layer must be scheduled in a run loop or dispatch_queue_t for the delegate
	to receive callbacks.
	
	Only one schedule can be set.
 */
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

/*!
	\brief
	A layer must be scheduled in a run loop of dispatch_queue_t for the delegate
	to receive callbacks.
 
	Only one schedule can be set.
 */
- (void)scheduleInQueue:(dispatch_queue_t)queue;

@end
