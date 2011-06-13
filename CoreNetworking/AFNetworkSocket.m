//
//  AFSocket.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkSocket.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <objc/runtime.h>

#import "AFNetworkFunctions.h"
#import "AFNetworkConstants.h"

@implementation AFNetworkSocket

@dynamic delegate;
@synthesize socket=_socket;

static void AFSocketCallback(CFSocketRef listenSocket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	AFNetworkSocket *self = [[(AFNetworkSocket *)info retain] autorelease];
	NSCParameterAssert(listenSocket == self->_socket);
	
	switch (type) {
		case kCFSocketAcceptCallBack:
		{	
			AFNetworkSocket *newSocket = [[[[self class] alloc] initWithLowerLayer:nil] autorelease];
			
			CFSocketContext context = {0};
			context.info = newSocket;
			
			newSocket->_socket = (CFSocketRef)CFMakeCollectable(CFSocketCreateWithNative(kCFAllocatorDefault, *(CFSocketNativeHandle *)data, 0, AFSocketCallback, &context));
			newSocket->_socketRunLoopSource = (CFRunLoopSourceRef)CFMakeCollectable(CFSocketCreateRunLoopSource(kCFAllocatorDefault, newSocket->_socket, 0));
			
			if ([self.delegate respondsToSelector:@selector(networkLayer:didAcceptConnection:)]) {
				[self.delegate networkLayer:self didAcceptConnection:newSocket];
			}
			
			break;
		}
		default:
		{
			NSLog(@"%s, socket %p, received unexpected CFSocketCallBackType %lu", __PRETTY_FUNCTION__, self, type);
			break;
		}
	}
	
	[pool drain];
}

- (id)initWithHostSignature:(const CFSocketSignature *)signature {
	self = [self init];
	if (self == nil) return nil;
	
	_signature = malloc(sizeof(CFSocketSignature));
	memcpy(_signature, signature, sizeof(CFSocketSignature));
	CFRetain(_signature->address);
	
	CFSocketContext context = {0};
	context.info = self;
	
	_socket = (CFSocketRef)CFMakeCollectable(CFSocketCreate(kCFAllocatorDefault, signature->protocolFamily, signature->socketType, signature->protocol, kCFSocketAcceptCallBack, AFSocketCallback, &context));
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

- (id)initWithNativeHandle:(CFSocketNativeHandle)handle {
	self = [self init];
	if (self == nil) return nil;
	
	CFSocketContext context = {0};
	context.info = self;
	
	_socket = (CFSocketRef)CFMakeCollectable(CFSocketCreateWithNative(kCFAllocatorDefault, handle, (CFOptionFlags)0, AFSocketCallback, &context));
	_socketRunLoopSource = (CFRunLoopSourceRef)CFMakeCollectable(CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0));
	
	return self;
}

- (void)finalize {	
	if (_signature != NULL) {
		if (_signature->address != NULL) {
			CFRelease(_signature->address);
		}
		free(_signature);
	}
	
	[super finalize];
}

- (void)dealloc {
	[self close];
	
	if (_signature != NULL) {
		if (_signature->address != NULL) {
			CFRelease(_signature->address);
		}
		free(_signature);
	}
	
	CFRelease(_socket);
	CFRelease(_socketRunLoopSource);
	
	[super dealloc];
}

- (void)open {
	NSParameterAssert(_signature != NULL);
	
	CFSocketError socketError = CFSocketSetAddress(_socket, _signature->address);
	if (socketError != kCFSocketSuccess) {
		NSInteger errorCode = AFNetworkSocketErrorUnknown;
		if (socketError == kCFSocketTimeout) {
			errorCode = AFNetworkSocketErrorTimeout;
		}
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   NSLocalizedStringFromTableInBundle(@"Couldn't connect to remote host", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkSocket couldn't open error description"), NSLocalizedDescriptionKey,
								   nil];
		NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:errorCode userInfo:errorInfo];
		
		[self.delegate networkLayer:self didReceiveError:error];
		return;
	}
	
	[self.delegate networkLayerDidOpen:self];
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
		[description appendFormat:@"\tAddress: %@\n", AFNetworkSocketAddressToPresentation((NSData *)[NSMakeCollectable(CFSocketCopyAddress(_socket)) autorelease])];
		[description appendFormat:@"\tPort: %ld\n", ntohs(((struct sockaddr_in *)CFDataGetBytePtr((CFDataRef)[NSMakeCollectable(CFSocketCopyAddress(_socket)) autorelease]))->sin_port)];
	}
	
	[description appendString:@"}"];
	
	return description;
}

- (void)scheduleInRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode {
	CFRunLoopAddSource([loop getCFRunLoop], _socketRunLoopSource, (CFStringRef)mode);
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode {
	CFRunLoopRemoveSource([loop getCFRunLoop], _socketRunLoopSource, (CFStringRef)mode);
}

- (id)localAddress {
	CFDataRef addr = (CFDataRef)[NSMakeCollectable(CFSocketCopyAddress(_socket)) autorelease];
	return (id)addr;
}

- (id)peer {
	id peer = [NSMakeCollectable(CFHostCreateWithAddress(kCFAllocatorDefault, (CFDataRef)[self peerAddress])) autorelease];
	return peer;
}

- (id)peerAddress {
	CFDataRef addr = (CFDataRef)[NSMakeCollectable(CFSocketCopyPeerAddress(_socket)) autorelease];
	return (id)addr;
}

@end
