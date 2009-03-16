//
//  AFSocket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AFNetworkLayer;

/*!
	@class
	@abstract	An AFSocket is designed to be a hosting socket, it will spawn more sockets upon revieving inbound connections
 */
@interface AFSocket : NSObject <AFNetworkLayer> {
	id _delegate;
	NSUInteger _socketFlags;
	
	__strong CFRunLoopRef _runLoop;
	
	__strong CFSocketRef _socket;
	__strong CFRunLoopSourceRef _socketRunLoopSource;
}

/*!
	@method
	@abstract	Do NOT use this method to create a host AFSocket, use the instantiator below
	@discussion	This is called to spawn a new peer socket when AFSocket receives an incoming connection you can override it
 */
+ (id)newSocketWithNativeSocket:(CFSocketNativeHandle)socket;

/*!
	@method
	@abstract	A socket is created with the given characteristics and the address is set
	@discussion	If the socket cannot be created they return nil
	@param		Providing the |delegate| in the instantiator is akin to creating a CFSocket with the callback function
 */
- (id)initWithSignature:(const CFSocketSignature *)signature delegate:(id)delegate;

@end
