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
#import <objc/runtime.h>

#import "AmberFoundation/AFPriorityProxy.h"

#import "AFNetworkFunctions.h"
#import "AFNetworkConstants.h"

@interface AFSocket ()

@end

@interface AFSocket (Private)
- (void)_close;
@end

@implementation AFSocket

@dynamic lowerLayer, delegate;

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

- (id)initWithLowerLayer:(id <AFNetworkLayer>)layer {
	self = [super initWithLowerLayer:layer];
	if (self == nil) return nil;
	
	CFSocketRef socket = (CFSocketRef)layer;
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = self;
	
	_socket = CFSocketCreateWithNative(kCFAllocatorDefault, CFSocketGetNative(socket), 0, AFSocketCallback, &context);
	
	_socketRunLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
	
	return self;
}

- (id)initWithSignature:(const CFSocketSignature *)signature callbacks:(CFOptionFlags)options {
	self = [self init];
	if (self == nil) return nil;
	
	_signature = NSAllocateCollectable(sizeof(CFSocketSignature), NSScannedOption);
	objc_memmove_collectable(_signature, signature, sizeof(CFSocketSignature));
	// Note: this is to keep things tickety boo under GC and otherwise
	NSMakeCollectable(CFRetain(_signature->address));
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = self;
	
	_socket = NSMakeCollectable(CFSocketCreate(kCFAllocatorDefault, signature->protocolFamily, signature->socketType, signature->protocol, options, AFSocketCallback, &context));
	
	if (_socket == NULL) {
		[self release];
		return nil;
	}
	
	_socketRunLoopSource = NSMakeCollectable(CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0));
	
	return self;
}

- (void)finalize {
	[self _close];
	
	if ([NSGarbageCollector defaultCollector] == nil) return;
	[super finalize];
}

- (void)dealloc {
	[self finalize];
	
	if (_signature != NULL)
		if (_signature->address != NULL)
			CFRelease(_signature->address);
	
	free(_signature);
	
	CFRelease(_socket);
	CFRelease(_socketRunLoopSource);
	
	[super dealloc];
}

- (void)open {
	CFSocketError socketError = kCFSocketError;
	
	if (_signature != NULL) {
		socketError = CFSocketSetAddress(_socket, _signature->address);
		
		if (socketError == kCFSocketSuccess) {
			[self.delegate layerDidOpen:self];
			return;
		}
	}
	
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketError", @"AFSocket", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Couldn't open socket.", nil), NSLocalizedDescriptionKey,
							  nil];
	
	AFNetworkingErrorCode errorCode = AFSocketErrorUnknown;
	if (socketError == kCFSocketTimeout) errorCode = AFSocketErrorTimeout;
	
	NSError *error = [NSError errorWithDomain:AFNetworkingErrorDomain code:errorCode userInfo:userInfo];
	[self.delegate layer:self didNotOpen:error];
}

- (BOOL)isOpen {
	return CFSocketIsValid(_socket);
}

- (void)close {
	[self _close];
}

- (BOOL)isClosed {
	return !([self isOpen]);
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@"{\n"];
	
	if (_socket != NULL) {
		char buffer[INET6_ADDRSTRLEN]; // Note: because the -description method is used only for debugging, we can use a fixed length buffer
		sockaddr_ntop((const struct sockaddr *)CFDataGetBytePtr((CFDataRef)[NSMakeCollectable(CFSocketCopyAddress(_socket)) autorelease]), buffer, INET6_ADDRSTRLEN);
		
		[description appendFormat:@"\tAddress: %s\n", buffer, nil];
		[description appendFormat:@"\tPort: %ld\n", ntohs(((struct sockaddr_in *)CFDataGetBytePtr((CFDataRef)[NSMakeCollectable(CFSocketCopyAddress(_socket)) autorelease]))->sin_port), nil];
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

- (CFHostRef)peer {
	CFDataRef addr = CFSocketCopyAddress(_socket);
	CFHostRef peer = (CFHostRef)[NSMakeCollectable(CFHostCreateWithAddress(kCFAllocatorDefault, addr)) autorelease];
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
		_socket = NULL;
	}
	
	_socketRunLoopSource = NULL;
}

@end
