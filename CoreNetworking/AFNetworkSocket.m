//
//  AFSocket.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFNetworkSocket.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <objc/runtime.h>

#import "AmberFoundation/AFPriorityProxy.h"

#import "AFNetworkFunctions.h"
#import "AFNetworkConstants.h"

@implementation AFNetworkSocket

@dynamic delegate;
@synthesize socket=_socket;

static void AFSocketCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	AFNetworkSocket *self = [[(AFNetworkSocket *)info retain] autorelease];
	NSCParameterAssert(socket == self->_socket);
	
	switch (type) {
		case kCFSocketAcceptCallBack:
		{	
			AFNetworkSocket *newSocket = [[[[self class] alloc] initWithLowerLayer:nil] autorelease];
			
			CFSocketContext context;
			memset(&context, 0, sizeof(CFSocketContext));
			context.info = newSocket;
			
			newSocket->_socket = CFSocketCreateWithNative(kCFAllocatorDefault, *(CFSocketNativeHandle *)data, 0, AFSocketCallback, &context);
			newSocket->_socketRunLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, newSocket->_socket, 0);
			
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

- (id)initWithSignature:(const CFSocketSignature *)signature callbacks:(CFOptionFlags)options {
	self = [self init];
	if (self == nil) return nil;
	
	_signature = malloc(sizeof(CFSocketSignature));
	memcpy(_signature, signature, sizeof(CFSocketSignature));
	CFRetain(_signature->address);
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = self;
	
	_socket = (CFSocketRef)CFMakeCollectable(CFSocketCreate(kCFAllocatorDefault, signature->protocolFamily, signature->socketType, signature->protocol, options, AFSocketCallback, &context));
	_socketRunLoopSource = (CFRunLoopSourceRef)CFMakeCollectable(CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0));
	
#if DEBUGFULL
	int reuseAddr = 1;
	
	int sockoptError = 0;
	sockoptError = setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, &reuseAddr, sizeof(reuseAddr));
#pragma unused (sockoptError)
#endif
	
	if (_socket == NULL) {
		[self release];
		return nil;
	}
	
	return self;
}

- (void)finalize {	
	if (_signature->address != NULL)
		CFRelease(_signature->address);
	
	free(_signature);
	
	[super finalize];
}

- (void)dealloc {
	[self close];
	
	if (_signature != NULL) {
		if (_signature->address != NULL) CFRelease(_signature->address);
		free(_signature);
	}
	
	CFRelease(_socket);
	CFRelease(_socketRunLoopSource);
	
	[super dealloc];
}

- (void)open {
	NSParameterAssert(_signature != NULL);
	
	CFSocketError socketError = kCFSocketError;
	socketError = CFSocketSetAddress(_socket, _signature->address);
	
	if (socketError == kCFSocketSuccess) {
		[self.delegate layerDidOpen:self];
		return;
	}
	
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketError", @"AFSocket", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Couldn't open socket.", nil), NSLocalizedDescriptionKey,
							  nil];
	
	AFNetworkingErrorCode errorCode = AFNetworkSocketErrorUnknown;
	if (socketError == kCFSocketTimeout) errorCode = AFNetworkSocketErrorTimeout;
	
	NSError *error = [NSError errorWithDomain:AFNetworkingErrorDomain code:errorCode userInfo:userInfo];
	[self.delegate layer:self didNotOpen:error];
}

- (BOOL)isOpen {
	return CFSocketIsValid(_socket);
}

- (void)close {
	if ([self isClosed]) return;
	
	CFSocketInvalidate(_socket);
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
	CFDataRef addr = (CFDataRef)[NSMakeCollectable(CFSocketCopyAddress(_socket)) autorelease];
	CFHostRef peer = (CFHostRef)[NSMakeCollectable(CFHostCreateWithAddress(kCFAllocatorDefault, (CFDataRef)addr)) autorelease];
	return peer;
}

@end
