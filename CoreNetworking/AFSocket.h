//
//  AFSocket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AFSocket : NSObject {
	id _delegate;
	NSUInteger _socketFlags;
	
	__strong CFRunLoopRef _runLoop;
	
#if 1
	/*
	 These are only needed for a host socket
	 */
	__strong CFSocketRef _socket;
	__strong CFRunLoopSourceRef _socketRunLoopSource;
#endif
}

/*
 * Host Initialisers
 *	These return nil if the socket can't be created
 */

/*!
	@method
	@abstract	A socket is created with the given characteristics and the address is set
 */
+ (id)hostWithSignature:(const CFSocketSignature *)signature;

/*!
	@method
	@abstract	This should not be called to create an AFSocket, use one of the class methods above
	@discussion	This is called to spawn a new socket when AFSocket receives an incoming connection
 */
- (id)initWithNativeSocket:(CFSocketNativeHandle)socket;

@end
