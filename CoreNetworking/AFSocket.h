//
//  AFSocket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkLayers.h"

@protocol AFSocketControlDelegate;

/*!
	@class
	@abstract	An AFSocket is designed to be a hosting socket
	@discussion	The purpose of this class is to spawn more sockets upon revieving inbound connections
				If you instantiate a subclass it will spawn instances of your subclass, pretty convenient!
 */
@interface AFSocket : NSObject <AFNetworkLayer> {
 @private
	id <AFSocketControlDelegate, AFNetworkLayerHostDelegate> _delegate;
	
	__strong CFRunLoopRef _runLoop;
	
	NSUInteger _socketFlags;
	
	__strong CFSocketRef _socket;
	__strong CFRunLoopSourceRef _socketRunLoopSource;
}

/*!
	@method
	@abstract	A socket is created with the given characteristics and the address is set
	@discussion	If the socket cannot be created they return nil
	@param		Providing the |delegate| in the instantiator is akin to creating a CFSocket with the callback function
 */
- (id)initWithSignature:(const CFSocketSignature *)signature delegate:(id <AFSocketControlDelegate, AFNetworkLayerHostDelegate>)delegate;

/*!
	@property
 */
@property (assign) id <AFSocketControlDelegate, AFNetworkLayerHostDelegate> delegate;

/*!
	@method
	@abstract	This may be used to extract the socket address
 */
- (CFSocketRef)lowerLayer;

@end

@protocol AFSocketControlDelegate <NSObject>

 @optional

/*!
	@method
	@abstract	defaults to CFRunLoopMain() if unimplemented
	@discussion	This is done in a delegate callback to remove the burden of scheduling newly spawned accept() sockets
 */
- (CFRunLoopRef)socketShouldScheduleWithRunLoop:(AFSocket *)socket;

@end
