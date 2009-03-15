//
//  AFSocket.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFSocket.h"

@implementation AFSocket

static void AFSocketCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFSocket *self = [[(AFSocket *)pInfo retain] autorelease];
	NSCParameterAssert(socket == self->_socket);
	
	switch (type) {
		case kCFSocketConnectCallBack:
		{
			// The data argument is either NULL or a pointer to an SInt32 error code, if the connect failed.			
			[self doSocketOpen:socket withCFSocketError:(pData != NULL ? kCFSocketError : kCFSocketSuccess)];
			break;
		}
		case kCFSocketAcceptCallBack:
		{
			[self doAcceptWithSocket:*((CFSocketNativeHandle *)pData)];
			break;
		}
		default:
		{
			NSLog(@"%s, socket %p, received unexpected CFSocketCallBackType %d.", __PRETTY_FUNCTION__, self, type);
			break;
		}
	}
	
	[pool drain];
}

+ (id)hostWithSignature:(const CFSocketSignature *)signature {
	AFSocket *socket = [[self alloc] init];
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = socket;
	
	socket->_socket = CFSocketCreateWithSocketSignature(kCFAllocatorDefault, signature, kCFSocketAcceptCallBack, AFSocketCallback, &context);
	
	if (socket->_socket == NULL) {
		[socket release];
		return nil;
	}
	
	{
#warning shift this to the -open method?
		socket->_socketRunLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket->_socket, 0);
		
		CFRunLoopRef *loop = &socket->_runLoop;
		if ([socket->_delegate respondsToSelector:@selector(socketShouldScheduleWithRunLoop:)]) {
			*loop = [socket->_delegate socketShouldScheduleWithRunLoop:socket];
		} if (*loop == NULL) *loop = CFRunLoopGetMain();
		
		CFRunLoopAddSource(*loop, socket->_socketRunLoopSource, kCFRunLoopDefaultMode);
	}
	
	return socket;
}

- (void)dealloc {
	CFSocketInvalidate(_socket);
	CFRelease(_socket);
	
	CFRelease(_socketRunLoopSource);
	
	[super dealloc];
}

- (void)close {
	if (_socket != NULL) {
		CFSocketInvalidate(_socket);
		CFRelease(_socket);
	}
	
	if (_socketRunLoopSource != NULL) CFRelease(_socketRunLoopSource);
}

@end
