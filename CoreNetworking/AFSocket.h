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
	id <AFSocketControlDelegate> _delegate;
	NSUInteger _socketFlags;
	
	__strong CFRunLoopRef _runLoop;
	
	__strong CFSocketRef _socket;
	__strong CFRunLoopSourceRef _socketRunLoopSource;
}

/*!
	@method
	@abstract	Do NOT use this method to create a _host_ AFSocket, use the instantiator below
	@discussion	This is called to spawn a new peer socket when AFSocket receives an incoming connection you can override it
				For clarification, the return value SHOULD be autoreleased
 */
+ (id)newSocketWithNativeSocket:(CFSocketNativeHandle)socket;

/*!
	@method
	@abstract	A socket is created with the given characteristics and the address is set
	@discussion	If the socket cannot be created they return nil
	@param		Providing the |delegate| in the instantiator is akin to creating a CFSocket with the callback function
 */
- (id)initWithSignature:(const CFSocketSignature *)signature delegate:(id)delegate;

/*!
	@property
 */
@property (assign) id <AFSocketControlDelegate> delegate;

/*!
	@method
	@abstract	This may be used to extract the address and port in use
 */
- (CFSocketRef)lowerLayer;

@end

@protocol AFSocketControlDelegate

 @optional

/*!
	@method
	@abstract	Asynchronous callbacks can be scheduled in another run loop, defaults to CFRunLoopMain() if unimplemented
	@discussion	This is done in a delegate callback to remove the burden of scheduling newly spawned accept() sockets
 */
- (CFRunLoopRef)socketShouldScheduleWithRunLoop:(AFSocket *)socket;

@end
