//
//  AFSocket.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFSocket.h"

@implementation AFSocket

@synthesize delegate=_delegate;

+ (id)newSocketWithNativeSocket:(CFSocketNativeHandle)socket {
	
}

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

- (id)initWithSignature:(const CFSocketSignature *)signature delegate:(id)delegate {
	[self init];
	
	_delegate = delegate;
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = self;
	
	_socket = CFSocketCreateWithSocketSignature(kCFAllocatorDefault, signature, kCFSocketAcceptCallBack, AFSocketCallback, &context);
	
	if (_socket == NULL) {
		[self release];
		return nil;
	}
	
	{
		if ([self.delegate respondsToSelector:@selector(socketShouldScheduleWithRunLoop:)]) {
			_runLoop = [_delegate socketShouldScheduleWithRunLoop:self];
		} if (_runLoop == NULL) _runLoop = CFRunLoopGetMain();
	
		_socketRunLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
		CFRunLoopAddSource(_runLoop, _socketRunLoopSource, kCFRunLoopDefaultMode);
	}
	
	return self;
}

/*!
	@method
	@abstract	This has been refactored into a separate method so that -dealloc can 'close' the socket without calling the public -close method
 */
- (void)_close {
	if (_socket != NULL) {
		CFSocketInvalidate(_socket);
		
		CFRelease(_socket);
		_socket = NULL;
	}
	
	if (_socketRunLoopSource != NULL) {
		// Note: invalidating the socket invalidates its source too
		CFRelease(_socketRunLoopSource);
		_socketRunLoopSource = NULL;
	}
}

- (void)dealloc {
	[self _close];
	
	[super dealloc];
}

- (void)close {
	[self _close];
}

- (CFSocketRef)lowerLayer {
	return _socket;
}

@end
