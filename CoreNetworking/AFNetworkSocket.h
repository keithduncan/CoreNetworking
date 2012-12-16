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

@protocol AFNetworkSocketDelegate <AFNetworkConnectionLayerHostDelegate, AFNetworkConnectionLayerDelegate>

@end

/*!
	\brief
	A very simple Objective-C wrapper around CFSocketRef.
	
	\details
	Create more `AFNetworkSocket` objects upon revieving inbound connections.
 */
@interface AFNetworkSocket : AFNetworkLayer <AFNetworkConnectionLayer> {
 @private
	AFNETWORK_STRONG CFSocketSignature *_signature;
	
	AFNETWORK_STRONG CFSocketRef _socket;
	NSUInteger _socketFlags;
	
	struct {
		AFNETWORK_STRONG CFTypeRef _runLoopSource;
		void *_dispatchSource;
	} _sources;
}

/*!
	\brief
	Host Initialiser.
	This is not governed by a protocol, luckily `AFConnectionServer` can instantiate this class specifically.
	A socket is created with the given characteristics and the address is set.
	
	\details
	If the socket cannot be created they return nil.
 */
- (id)initWithSocketSignature:(CFSocketSignature const *)signature;

/*!
	\brief
	Connect initialiser.
	This is not called by the framework, it is provided for you to bring exising FDs into the object graph.
	
	\details
	Since AFNetworkSocket doesnt actually perform any read/write operations; this method doesn't take any options.
	This is intended to provide a socket to a higher layer.
 */
- (id)initWithNativeHandle:(CFSocketNativeHandle)handle;

@property (assign, nonatomic) id <AFNetworkSocketDelegate> delegate;

/*!
	\brief
	Offers inline synchronous error reporting.
 */
- (BOOL)open:(NSError **)errorRef;

/*!
	\brief
	This is not set as the lower layer because `AFNetworkSocket` shouldn't be thought of as sitting above `CFSocketRef`, it should be thought of *as* a `CFSocketRef`.
 */
@property (readonly, nonatomic) id local;
/*!
	\brief
	This returns the `-[AFNetworkSocket socket]` local address.
 */
@property (readonly, nonatomic) id localAddress;

/*!
	\brief
	This creates a CFHostRef wrapping the `-peerAddress`.
 */
@property (readonly, nonatomic) id peer;
/*!
	\brief
	This returns the `-[AFNetworkSocket socket]` peer address.
	This is likely to be of most use when determining the reachbility of an endpoint.
 */
@property (readonly, nonatomic) id peerAddress;

@end
