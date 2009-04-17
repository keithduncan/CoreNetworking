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

#import "AmberFoundation/AFPriorityProxy.h"

#import "AFNetworkFunctions.h"

@interface AFSocket (Private)
- (void)_close;
@end

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

- (id)initWithLowerLayer:(id)layer delegate:(id)delegate {
	self = [self init];
	
	CFSocketRef socket = (CFSocketRef)layer;
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = self;
	
	_socket = CFSocketCreateWithNative(kCFAllocatorDefault, CFSocketGetNative(socket), 0, AFSocketCallback, &context);
	
	_delegate = delegate;
	
	return self;
}

- (id)initWithSignature:(const CFSocketSignature *)signature callbacks:(CFOptionFlags)options delegate:(id <AFSocketControlDelegate, AFSocketHostDelegate>)delegate {
	self = [self init];
	
	_signature = (CFSocketSignature *)malloc(sizeof(CFSocketSignature));
	memcpy(_signature, signature, sizeof(CFSocketSignature));
	// Note: this is here for non-GC
	CFRetain(_signature->address);
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = self;
	
	_socket = CFSocketCreate(kCFAllocatorDefault, signature->protocolFamily, signature->socketType, signature->protocol, options, AFSocketCallback, &context);
	if (_socket == NULL) {
		[self release];
		return nil;
	}
	
	_socketRunLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);

#if 0
	int sockoptError = 0, reuseAddr = 1;
	sockoptError = setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, &reuseAddr, sizeof(reuseAddr));
	if (sockoptError != 0) {
		[self release];
		return nil;
	}
#endif
	
	_delegate = delegate;
	
	return self;
}

- (void)dealloc {
	[self _close];
	
	if (_signature != NULL) {
		if (_signature->address != NULL)
			CFRelease(_signature->address);
	}
	
	[super dealloc];
}

- (AFPriorityProxy *)delegateProxy:(AFPriorityProxy *)proxy {
	if (proxy == nil) proxy = [[[AFPriorityProxy alloc] init] autorelease];
	
	if ([_delegate respondsToSelector:@selector(delegateProxy:)]) proxy = [(id)_delegate delegateProxy:proxy];
	[proxy insertTarget:_delegate atPriority:0];
	
	return proxy;
}

- (id <AFSocketControlDelegate, AFSocketHostDelegate>)delegate {
	return (id)[self delegateProxy:nil];
}

- (void)open {
	CFSocketError socketError = kCFSocketSuccess;
	
	if (_signature != NULL) {
		socketError = CFSocketSetAddress(_socket, _signature->address);
	}
	
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

- (void)close {
	[self _close];
}

- (BOOL)isClosed {
	return ![self isOpen];
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@" {\n"];
	
	if (_socket != NULL) {
		char buffer[INET6_ADDRSTRLEN]; // Note: because the -description method is used only for debugging, we can use a fixed length buffer
		sockaddr_ntop((const struct sockaddr *)CFDataGetBytePtr((CFDataRef)[(id)CFSocketCopyAddress(_socket) autorelease]), buffer, sizeof(buffer));
		
		[description appendFormat:@"\tAddress: %s\n", buffer, nil];
		[description appendFormat:@"\tPort: %ld\n", ntohs(((struct sockaddr_in *)CFDataGetBytePtr((CFDataRef)[(id)CFSocketCopyAddress(_socket) autorelease]))->sin_port), nil];
	}
	
	[description appendString:@"}"];
	
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

- (CFHostRef)peer {
	CFDataRef addr = CFSocketCopyAddress(_socket);
	CFHostRef peer = [(id)CFMakeCollectable(CFHostCreateWithAddress(kCFAllocatorDefault, addr)) autorelease];
	CFRelease(addr);
	
	return peer;
}

@end

@implementation AFSocket (Private)

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

@end
