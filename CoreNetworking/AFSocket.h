//
//  AFSocket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFConnectionLayer.h"

/*!
	@class
	@abstract	An simple object-oriented wrapper around CFSocket
	@discussion	The current purpose of this class is to spawn more sockets upon revieving inbound connections
 */
@interface AFSocket : AFNetworkLayer <AFConnectionLayer> {
 @private
	__strong CFSocketSignature *_signature;
	
	__strong CFSocketRef _socket;
	__strong CFRunLoopSourceRef _socketRunLoopSource;
}

/*
 *	Inbound Initialiser
 *		This is used to bring a stack online when receiving an inbound connection.
 */

/*!
	@method
	@param		|lowerLayer| is expected to be a CFSocketRef from which the native socket can be extracted.
 */
- (id)initWithLowerLayer:(id <AFTransportLayer>)layer;

/*
 *	Host Initialiser
 *		This is not governed by a protocol, luckily the AFConnectionServer knows how to create this class specifically.
 */

/*!
	@method
	@abstract	A socket is created with the given characteristics and the address is set
	@discussion	If the socket cannot be created they return nil
 */
- (id)initWithSignature:(const CFSocketSignature *)signature callbacks:(CFOptionFlags)options;

/*!
	@property
 */
@property (assign) id <AFConnectionLayerHostDelegate, AFConnectionLayerControlDelegate> delegate;

/*!
	@property
	@abstract	This returns the <tt>CFSocket</tt> peer address wrapped in a CFHostRef
 */
@property (readonly) CFHostRef peer;

@end
