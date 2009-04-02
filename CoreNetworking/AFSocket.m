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

static void AFSocketCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	AFSocket *self = [[(AFSocket *)info retain] autorelease];
	NSCParameterAssert(socket == self->_socket);
	
	switch (type) {
		case kCFSocketAcceptCallBack:
		{
			AFSocket *newSocket = [[[[self class] alloc] init] autorelease];
			
			CFSocketContext context;
			memset(&context, 0, sizeof(CFSocketContext));
			context.info = newSocket;
			
			newSocket->_socket = CFSocketCreateWithNative(kCFAllocatorDefault, *(CFSocketNativeHandle *)data, 0, AFSocketCallback, &context);
			
			if ([self.delegate respondsToSelector:@selector(layer:didAcceptConnection:)])
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

- (id)initWithSignature:(const CFSocketSignature *)signature callbacks:(CFOptionFlags)options delegate:(id <AFSocketControlDelegate, AFSocketHostDelegate>)delegate {
	self = [self init];
	
	_signature = NSAllocateCollectable(sizeof(signature), NSScannedOption);
	objc_memmove_collectable(_signature, signature, sizeof(signature));
	// Note: this is here for non-GC
	CFRetain(_signature->address);
	
	_delegate = delegate;
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = self;
	
	_socket = CFSocketCreate(kCFAllocatorDefault, signature->protocolFamily, signature->socketType, signature->protocol, options, AFSocketCallback, &context);
	if (_socket == NULL) {
		[self release];
		return nil;
	}
	
	_socketRunLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
	
	int sockoptError = 0, reusePort = 1;
	sockoptError = setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, &reusePort, sizeof(reusePort));
	if (sockoptError != 0) {
		[self release];
		return nil;
	}
	
	return self;
}

- (void)open {
	CFSocketError socketError = CFSocketSetAddress(_socket, _signature->address);
	
	if (socketError == kCFSocketSuccess) {
		if ([self.delegate respondsToSelector:@selector(layerDidOpen:)])
			[self.delegate layerDidOpen:self];
		
		return;
	}
	
	if ([self.delegate respondsToSelector:@selector(layerDidNotOpen:)])
		[self.delegate layerDidNotOpen:self];
	
	return;
}

- (BOOL)isOpen {
	return CFSocketIsValid(_socket);
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

- (void)close {
	[self _close];
}

- (BOOL)isClosed {
	return ![self isOpen];
}

- (void)dealloc {
	[self _close];
	
	// Note: this is here for non-GC
	CFRelease(_signature->address);
	
	[super dealloc];
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@"\n"];
	
	if (_socket != NULL) {
		[description appendString:@"\tAddress: "];
		
		char buffer[INET6_ADDRSTRLEN]; // Note: because the -description method is used only for debugging, we can use fixed length buffer
		sockaddr_ntop((const struct sockaddr *)CFDataGetBytePtr((CFDataRef)[(id)CFSocketCopyAddress(_socket) autorelease]), buffer, sizeof(buffer));
		
		[description appendFormat:@"%s\n", buffer, nil];
		
		[description appendFormat:@"\tPort: %ld", ntohs(((struct sockaddr_in *)CFDataGetBytePtr((CFDataRef)[(id)CFSocketCopyAddress(_socket) autorelease]))->sin_port), nil];
	}
	
	return description;
}

- (void)scheduleInRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode {
	CFRunLoopAddSource(loop, _socketRunLoopSource, mode);
}

- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode {
	CFRunLoopRemoveSource(loop, _socketRunLoopSource, mode);
}

- (id)lowerLayer {
	return (id)_socket;
}

@end
