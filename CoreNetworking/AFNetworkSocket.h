//
//  AFNetworkSocket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFConnectionLayer.h"

/*!
	@brief
	A very simple Objective-C wrapper around CFSocketRef.
	
	@detail
	The purpose of this class is to spawn more sockets upon revieving inbound connections.
 */
@interface AFNetworkSocket : AFNetworkLayer <AFConnectionLayer> {
 @private
	__strong CFSocketSignature *_signature;
	
	__strong CFSocketRef _socket;
	
	__strong CFRunLoopSourceRef _socketRunLoopSource;
}

/*!
	@brief
	Host Initialiser.
	This is not governed by a protocol, luckily <tt>AFConnectionServer</tt> can instantiate this class specifically.
	A socket is created with the given characteristics and the address is set.
	
	@detail
	If the socket cannot be created they return nil.
 */
- (id)initWithSignature:(const CFSocketSignature *)signature callbacks:(CFOptionFlags)options;

/*!
	@brief
	
 */
@property (assign) id <AFConnectionLayerHostDelegate, AFConnectionLayerControlDelegate> delegate;

/*!
	@brief
	This is not set as the lower layer because <tt>AFNetworkSocket</tt> shouldn't be thought of as sitting above CFSocketRef, it should be thought of <em>as</em> a CFSocketRef.
 */
@property (readonly) CFSocketRef socket;

/*!
	@brief
	This returns the <tt>-[AFNetworkSocket socket]</tt> local address.
 */
@property (readonly) id localAddress;

/*!
	@brief
	This creates a CFHostRef wrapping the <tt>-peerAddress</tt>.
 */
@property (readonly) id peer;

/*!
	@brief
	This returns the <tt>-[AFNetworkSocket socket]</tt> peer address.
	This is likely to be of most use when determining the reachbility of an endpoint.
 */
@property (readonly) id peerAddress;

@end
