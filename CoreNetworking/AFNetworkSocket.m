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

#import "AFNetwork-Functions.h"
#import "AFNetwork-Constants.h"
#import "AFNetwork-Macros.h"

typedef AFNETWORK_ENUM(NSUInteger, _AFNetworkSocketFlags) {
	_AFNetworkSocketFlagsDidOpen	= 1UL << 0, // socket has been opened
	_AFNetworkSocketFlagsDidClose	= 1UL << 1, // socket has been closed
};

@interface AFNetworkSocket ()
@property (assign, nonatomic) AFNETWORK_STRONG __attribute__((NSObject)) CFSocketRef socket;
@property (assign, nonatomic) NSUInteger socketFlags;

- (void)_resumeSources;
@end

@implementation AFNetworkSocket

@dynamic delegate;
@synthesize socketFlags=_socketFlags;
@synthesize socket=_socket;

static void _AFNetworkSocketCallback(CFSocketRef listenSocket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	AFNetworkSocket *self = [[(AFNetworkSocket *)info retain] autorelease];
	NSCParameterAssert(listenSocket == self.socket);
	
	switch (type) {
		case kCFSocketAcceptCallBack:
		{
			CFSocketNativeHandle nativeHandle = *(CFSocketNativeHandle *)data;
			
			AFNetworkSocket *newSocket = [[[[self class] alloc] initWithNativeHandle:nativeHandle] autorelease];
			if (newSocket == nil) {
				close(nativeHandle);
				
				[pool drain];
				
				return;
			}
			
			if ([self.delegate respondsToSelector:@selector(networkLayer:didAcceptConnection:)]) {
				[self.delegate networkLayer:self didAcceptConnection:newSocket];
			}
			
			break;
		}
		default:
		{
			[pool drain];
			
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s, socket %p, received unexpected CFSocketCallBackType %lu", __PRETTY_FUNCTION__, self, type] userInfo:nil];
			break;
		}
	}
	
	[pool drain];
}

- (id)initWithSocketSignature:(const CFSocketSignature *)signature {
	self = [self init];
	if (self == nil) return nil;
	
	_signature = malloc(sizeof(CFSocketSignature));
	memcpy(_signature, signature, sizeof(CFSocketSignature));
	CFRetain(_signature->address);
	
	CFSocketContext context = {
		.info = self,
	};
	_socket = (CFSocketRef)CFSocketCreate(kCFAllocatorDefault, signature->protocolFamily, signature->socketType, signature->protocol, kCFSocketAcceptCallBack, _AFNetworkSocketCallback, &context);
	if (_socket == NULL) {
		[self release];
		return nil;
	}
	
#if DEBUGFULL
	int reuseAddr = 1;
	int sockoptError __attribute__((unused)) = setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, &reuseAddr, sizeof(reuseAddr));
#endif /* DEBUGFULL */
	
	return self;
}

- (id)initWithNativeHandle:(CFSocketNativeHandle)handle {
	self = [self init];
	if (self == nil) return nil;
	
	CFSocketContext context = {
		.info = self,
	};
	_socket = (CFSocketRef)CFSocketCreateWithNative(kCFAllocatorDefault, handle, (CFOptionFlags)0, _AFNetworkSocketCallback, &context);
	if (_socket == NULL) {
		[self release];
		return nil;
	}
	
	return self;
}

- (void)finalize {	
	if (_signature != NULL) {
		if (_signature->address != NULL) {
			CFRelease(_signature->address);
		}
		free(_signature);
	}
	
	CFSocketInvalidate(_socket);
	CFRelease(_socket);
	
	[super finalize];
}

- (void)dealloc {
	if (_signature != NULL) {
		if (_signature->address != NULL) {
			CFRelease(_signature->address);
		}
		free(_signature);
	}
	
	CFSocketInvalidate(_socket);
	CFRelease(_socket);
	
	if (_sources._runLoopSource != NULL) {
		CFRelease(_sources._runLoopSource);
		_sources._runLoopSource = NULL;
	}
	
	[super dealloc];
}

- (void)open {
	NSError *openError = nil;
	BOOL open = [self open:&openError];
	if (!open) {
		[self.delegate networkLayer:self didReceiveError:openError];
		return;
	}
	
	return;
}

- (BOOL)open:(NSError **)errorRef {
	NSParameterAssert(_sources._runLoopSource != NULL || _sources._dispatchSource != NULL);
	NSParameterAssert(self.delegate != nil);
	
	if ([self isOpen]) {
		return YES;
	}
	
	CFSocketSignature *signature = _signature;
	NSParameterAssert(signature != NULL);
	
	/*
		Note
		
		this implements the functionality of CFSocketSetAddress() as found in <http://opensource.apple.com/source/CF/CF-476.19/CFSocket.c>
		
		we reproduce it here instead of calling CFSocketSetAddress() directly because its return value doesn't give us access to the full gamut of errors
		
		we could assume that it calls bind()/listen() internally, but I'd rather avoid the assumption and implement the algorithm here explicitly
	 */
	
	CFSocketRef socket = self.socket;
	CFSocketNativeHandle nativeHandle = CFSocketGetNative(socket);
	
	int bindError = bind(nativeHandle, (const struct sockaddr *)CFDataGetBytePtr(signature->address), CFDataGetLength(signature->address));
	if (bindError != 0) {
		if (errorRef != NULL) {
			int underlyingErrorCode = errno;
			NSError *underlyingError = [NSError errorWithDomain:NSPOSIXErrorDomain code:underlyingErrorCode userInfo:nil];
			
			AFNetworkErrorCode errorCode = AFNetworkSocketErrorUnknown;
			switch (underlyingErrorCode) {
				case EPERM:
				{
					errorCode = AFNetworkSocketErrorListenerOpenNotPermitted;
					break;
				}
				case EADDRINUSE:
				{
					errorCode = AFNetworkSocketErrorListenerOpenAddressAlreadyUsed;
					break;
				}
			}
			
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									   NSLocalizedStringFromTableInBundle(@"Couldn\u2019t open a socket", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkSocket couldn't open error description"), NSLocalizedDescriptionKey,
									   underlyingError, NSUnderlyingErrorKey,
									   nil];
			*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:errorCode userInfo:errorInfo];
		}
		
		[self close];
		return NO;
	}
	
	listen(nativeHandle, 256);
	
	self.socketFlags = (self.socketFlags | _AFNetworkSocketFlagsDidOpen);
	[self.delegate networkLayerDidOpen:self];
	
	[self _resumeSources];
	
	return YES;
}

- (BOOL)isOpen {
	return ((self.socketFlags & _AFNetworkSocketFlagsDidOpen) == _AFNetworkSocketFlagsDidOpen);
}

- (void)close {
	if ([self isClosed]) {
		return;
	}
	self.socketFlags = (self.socketFlags | _AFNetworkSocketFlagsDidClose);
	
	CFSocketInvalidate(self.socket);
	
	[self.delegate networkLayerDidClose:self];
}

- (BOOL)isClosed {
	return ((self.socketFlags & _AFNetworkSocketFlagsDidClose) == _AFNetworkSocketFlagsDidClose);
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@"{\n"];
	
	NSData *localAddress = (NSData *)[NSMakeCollectable(CFSocketCopyAddress(self.socket)) autorelease];
	if (localAddress != NULL) {
		[description appendFormat:@"\tAddress: %@\n", AFNetworkSocketAddressToPresentation(localAddress, NULL)];
		[description appendFormat:@"\tPort: %ld\n", (unsigned long)af_sockaddr_in_read_port((const struct sockaddr_storage *)CFDataGetBytePtr((CFDataRef)localAddress))];
	}
	
	[description appendString:@"}"];
	
	return description;
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(_sources._dispatchSource == NULL);
	
	[super scheduleInRunLoop:runLoop forMode:mode];
	
	if (_sources._runLoopSource == NULL) {
		_sources._runLoopSource = (CFRunLoopSourceRef)CFMakeCollectable(CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0));
	}
	
	CFRunLoopAddSource([runLoop getCFRunLoop], _sources._runLoopSource, (CFStringRef)mode);
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(_sources._runLoopSource != NULL);
	
	[super unscheduleFromRunLoop:runLoop forMode:mode];
	
	CFRunLoopRemoveSource([runLoop getCFRunLoop], _sources._runLoopSource, (CFStringRef)mode);
}

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	NSParameterAssert(_sources._runLoopSource == NULL);
	
	[super scheduleInQueue:queue];
	
	if (queue != NULL) {
		if (_sources._dispatchSource == NULL) {
			CFSocketRef socket = _socket;
			CFSocketNativeHandle nativeHandle = CFSocketGetNative(socket);
			
			dispatch_source_t newSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, nativeHandle, 0, queue);
			dispatch_source_set_event_handler(newSource, ^ {
				struct sockaddr *newSocketAddress = alloca(SOCK_MAXADDRLEN);
				socklen_t newSocketAddressLength = sizeof(newSocketAddress);
				CFSocketNativeHandle newNativeSocket = accept(nativeHandle, newSocketAddress, &newSocketAddressLength);
				if (newNativeSocket == -1) {
					switch (errno) {
						case EBADF: /* socket is not a valid file descriptor. */
							break;
						case ECONNABORTED: /* The connection to socket has been aborted. */
							break;
						case EFAULT: /* The address parameter is not in a writable part of the user address space. */
							break;
						case EINTR: /* The accept() system call was terminated by a signal. */
							break;
						case EINVAL: /* socket is unwilling to accept connections. */
							break;
						case EMFILE: /* The per-process descriptor table is full. */
									 /* The system file table is full. */
							break;
						case ENOMEM: /* Insufficient memory was available to complete the operation. */
							break;
						case ENOTSOCK: /* socket references a file type other than a socket. */
							break;
						case EOPNOTSUPP: /* socket is not of type SOCK_STREAM and thus does not accept connections. */
							break;
						case EWOULDBLOCK: /* socket is marked as non-blocking and no connections are present to be accepted. */
							break;
					}
#warning handle these errors
					return;
				}
				
				NSData *newSocketAddressData = [NSData dataWithBytes:&newSocketAddress length:newSocketAddressLength];
				
				_AFNetworkSocketCallback(socket, kCFSocketAcceptCallBack, (CFDataRef)newSocketAddressData, &newNativeSocket, self);
			});
			dispatch_source_set_cancel_handler(newSource, ^ {
				[self close];
			});
			
			_sources._dispatchSource = newSource;
			return;
		}
		
		dispatch_set_target_queue(_sources._dispatchSource, queue);
		return;
	}
	
	if (_sources._dispatchSource != NULL) {
		dispatch_source_cancel(_sources._dispatchSource);
		dispatch_release(_sources._dispatchSource);
		_sources._dispatchSource = NULL;
	}
}

#endif

- (void)_resumeSources {
	if (_sources._runLoopSource != NULL) {
		//nop
	}
	
#if defined(DISPATCH_API_VERSION)
	if (_sources._dispatchSource != NULL) {
		dispatch_resume(_sources._dispatchSource);
	}
#endif /* defined(DISPATCH_API_VERSION) */
}

- (id)local {
	return (id)self.socket;
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
