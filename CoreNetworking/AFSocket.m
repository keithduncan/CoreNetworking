//
//  AFSocket.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFSocket.h"

#import <sys/socket.h>
#import <netinet/in.h>

#import "AFNetworkFunctions.h"

@implementation AFSocket

@synthesize delegate=_delegate;

+ (id)socketWithNativeSocket:(CFSocketNativeHandle)socket delegate:(id)delegate {
	return nil;
}

static void AFSocketCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	AFSocket *self = [[(AFSocket *)info retain] autorelease];
	NSCParameterAssert(socket == self->_socket);
	
	switch (type) {
		case kCFSocketAcceptCallBack:
		{
			AFSocket *newSocket = [[self class] socketWithNativeSocket:*((CFSocketNativeHandle *)data) delegate:self.delegate];
			
			if (newSocket != nil)
				[self.delegate layer:self didAcceptConnection:newSocket];
			
			break;
		}
		default:
		{
			NSLog(@"%s, socket %p, received unexpected CFSocketCallBackType %d.", __PRETTY_FUNCTION__, self, type, nil);
			break;
		}
	}
	
	[pool drain];
}

- (id)initWithSignature:(const CFSocketSignature *)signature delegate:(id <AFSocketControlDelegate, AFNetworkLayerHostDelegate>)delegate {
	[self init];
	
	_delegate = delegate;
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = self;
	
	_socket = CFSocketCreate(kCFAllocatorDefault, signature->protocolFamily, signature->socketType, signature->protocol, kCFSocketAcceptCallBack, AFSocketCallback, &context);
	if (_socket == NULL) {
		[self release];
		return nil;
	}
	
	int sockoptError = 0, reusePort = 1;
	sockoptError = setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, &reusePort, sizeof(reusePort));
	if (sockoptError != 0) {
		[self release];
		return nil;
	}
	
	CFSocketError socketError = CFSocketSetAddress(_socket, signature->address);
	if (socketError != kCFSocketSuccess) {
		[self release];
		return nil;
	}
	
	if ([self.delegate respondsToSelector:@selector(socketShouldScheduleWithRunLoop:)]) {
		_runLoop = [self.delegate socketShouldScheduleWithRunLoop:self];
	}
	if (_runLoop == NULL) _runLoop = CFRunLoopGetMain();
	
	_socketRunLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
	CFRunLoopAddSource(_runLoop, _socketRunLoopSource, kCFRunLoopDefaultMode);
	
	return self;
}

/*!
	@method
	@abstract	This has been refactored into a separate method so that -dealloc can 'close' the socket without calling the public -close method
	@discussion	These are set to NULL so that closing again, or deallocating doesn't crash the socket
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

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@"\n"];
	
	if (_socket != NULL) {
		[description appendString:@"\tAddress: "];
		
		char buffer[INET6_ADDRSTRLEN]; // Note: because the -description method is used only for debugging, we can use the IPv6 fixed length
		sockaddr_ntop((const struct sockaddr *)CFDataGetBytePtr((CFDataRef)[(id)CFSocketCopyAddress(_socket) autorelease]), buffer, INET6_ADDRSTRLEN);
		
		[description appendFormat:@"%s\n", buffer, nil];
		
		[description appendFormat:@"\tPort: %ld", ntohs(((struct sockaddr_in *)CFDataGetBytePtr((CFDataRef)[(id)CFSocketCopyAddress(_socket) autorelease]))->sin_port), nil];
	}
	
	return description;
}

- (void)close {
	[self _close];
}

- (CFSocketRef)lowerLayer {
	return _socket;
}

@end
