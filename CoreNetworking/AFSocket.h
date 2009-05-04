//
//  AFSocket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFNetworkObject.h"

#import "CoreNetworking/AFConnectionLayer.h"

@protocol AFSocketHostDelegate;
@protocol AFSocketControlDelegate;

/*!
	@class
	@abstract	An simple object-oriented wrapper around CFSocket
	@discussion	The current purpose of this class is to spawn more sockets upon revieving inbound connections
 */
@interface AFSocket : AFNetworkObject <AFConnectionLayer> {
 @private
	__strong CFSocketRef _socket;
	__strong CFSocketSignature *_signature;
	__strong CFRunLoopSourceRef _socketRunLoopSource;
}

/*
 *	Inbound Initialiser
 */

/*!
	@method
	@param		|lowerLayer| is expected to be a CFSocketRef that the native socket can be extracted from.
 */
- (id)initWithLowerLayer:(id <AFNetworkLayer>)layer;

/*
 *	Outbound Initialiser
 *		This is not governed by a protocol, luckily the AFConnectionServer knows how to create this class specifically.
 */

/*!
	@method
	@abstract	A socket is created with the given characteristics and the address is set
	@discussion	If the socket cannot be created they return nil
	@param		Providing the |delegate| in the instantiator is akin to creating a CFSocket with the callback function
 */
- (id)initWithSignature:(const CFSocketSignature *)signature callbacks:(CFOptionFlags)options delegate:(id <AFConnectionLayerHostDelegate, AFConnectionLayerControlDelegate>)delegate;

/*!
	@property
	@abstract	This returns the <tt>CFSocket</tt> peer address wrapped in a CFHostRef
 */
@property (readonly) CFHostRef peer;

/*!
	@property
 */
@property (assign) id <AFSocketHostDelegate, AFSocketControlDelegate> delegate;

@end

/*!
	@protocol
 */
@protocol AFSocketHostDelegate <AFConnectionLayerHostDelegate>

@end

/*!
	@protocol
 */
@protocol AFSocketControlDelegate <AFConnectionLayerControlDelegate>

@end
