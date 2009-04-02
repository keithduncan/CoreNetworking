//
//  AFSocket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkLayer.h"
#import "CoreNetworking/AFConnectionLayer.h"

@protocol AFSocketHostDelegate;
@protocol AFSocketControlDelegate;

/*!
	@class
	@abstract	An simple object-oriented wrapper around CFSocket
	@discussion	The current purpose of this class is to spawn more sockets upon revieving inbound connections
				
 */
@interface AFSocket : NSObject <AFConnectionLayer> {
 @private
	id <AFSocketControlDelegate, AFSocketHostDelegate> _delegate;
	
	__strong CFSocketSignature *_signature;
	
	NSUInteger _socketFlags;
	__strong CFSocketRef _socket;
	
	__strong CFRunLoopSourceRef _socketRunLoopSource;
}

/*
 *	Outbound Initialiser
 *		This is not goverened by a protocol, the AFConnectionServer knows how to create this class specifically
 */

/*!
	@method
	@abstract	A socket is created with the given characteristics and the address is set
	@discussion	If the socket cannot be created they return nil
	@param		Providing the |delegate| in the instantiator is akin to creating a CFSocket with the callback function
 */
- (id)initWithSignature:(const CFSocketSignature *)signature callbacks:(CFOptionFlags)options delegate:(id <AFConnectionLayerHostDelegate, AFConnectionLayerControlDelegate>)delegate;

/*!
	@method
	@abstract	This returns a CFSocketRef despite the weak type, this is to avoid compiler errors.
	@discussion	You may use this to extract the socket address for display purposes.
 */
- (id)lowerLayer;

/*!
	@property
 */
@property (assign) id <AFSocketHostDelegate, AFSocketControlDelegate> delegate;

@end

@protocol AFSocketHostDelegate <AFConnectionLayerHostDelegate>

@end

@protocol AFSocketControlDelegate <AFConnectionLayerControlDelegate>

@end
