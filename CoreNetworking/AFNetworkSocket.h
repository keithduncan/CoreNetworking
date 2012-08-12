//
//  AFNetworkSocket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetworkConnectionLayer.h"

#import "CoreNetworking/AFNetwork-Macros.h"

/*!
	\brief
	
 */
@protocol AFNetworkSocketDelegate <AFNetworkConnectionLayerHostDelegate, AFNetworkConnectionLayerDelegate>

@end

/*!
	\brief
	A very simple Objective-C wrapper around CFSocketRef.
	
	\details
	The purpose of this class is to spawn more sockets upon revieving inbound connections.
 */
@interface AFNetworkSocket : AFNetworkLayer <AFNetworkConnectionLayer> {
 @private
	AFNETWORK_STRONG CFSocketSignature *_signature;
	
	AFNETWORK_STRONG __attribute__((NSObject)) CFSocketRef _socket;
	NSUInteger _socketFlags;
	
	struct {
		AFNETWORK_STRONG __attribute__((NSObject)) CFRunLoopSourceRef _runLoopSource;
		AFNETWORK_STRONG void *_dispatchSource;
	} _sources;
}

/*!
	\brief
	Host Initialiser.
	This is not governed by a protocol, luckily <tt>AFConnectionServer</tt> can instantiate this class specifically.
	A socket is created with the given characteristics and the address is set.
	
	\details
	If the socket cannot be created they return nil.
 */
- (id)initWithSocketSignature:(const CFSocketSignature *)signature;

/*!
	\brief
	Connect initialiser.
	This is not called by the framework, it is provided for you to bring exising FDs into the object graph.
	
	\details
	Since AFNetworkSocket doesnt actually perform any read/write operations; this method doesn't take any options.
	This is intended to provide a socket to a higher layer.
 */
- (id)initWithNativeHandle:(CFSocketNativeHandle)handle;

/*!
	\brief
	
 */
@property (assign, nonatomic) id <AFNetworkSocketDelegate> delegate;

/*!
	\brief
	Offers inline synchronous error handling.
 */
- (BOOL)open:(NSError **)errorRef;

/*!
	\brief
	This is not set as the lower layer because <tt>AFNetworkSocket</tt> shouldn't be thought of as sitting above CFSocketRef, it should be thought of <em>as</em> a CFSocketRef.
 */
@property (readonly, nonatomic) id local;
/*!
	\brief
	This returns the <tt>-[AFNetworkSocket socket]</tt> local address.
 */
@property (readonly, nonatomic) id localAddress;

/*!
	\brief
	This creates a CFHostRef wrapping the <tt>-peerAddress</tt>.
 */
@property (readonly, nonatomic) id peer;
/*!
	\brief
	This returns the <tt>-[AFNetworkSocket socket]</tt> peer address.
	This is likely to be of most use when determining the reachbility of an endpoint.
 */
@property (readonly, nonatomic) id peerAddress;

@end
