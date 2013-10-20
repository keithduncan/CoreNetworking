//
//  AFSocket.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkSocket.h"

#import <sys/socket.h>
#import <sys/ioctl.h>
#define __APPLE_USE_RFC_3542
#import <netinet/in.h>
#import <objc/runtime.h>

#import "AFNetworkSchedule.h"
#import "AFNetworkDatagram.h"
#import "AFNetworkSocketOption.h"

#import "AFNetwork-Functions.h"
#import "AFNetwork-Constants.h"
#import "AFNetwork-Macros.h"

typedef AFNETWORK_OPTIONS(NSUInteger, _AFNetworkSocketFlags) {
	_AFNetworkSocketFlagsDidOpen	= 1UL << 0, // socket has been opened
	_AFNetworkSocketFlagsDidClose	= 1UL << 1, // socket has been closed
	
	_AFNetworkSocketFlagsListen		= 1UL << 2, // listen() succeeded
};

struct _AFNetworkSocket_CompileTimeAssertion {
	char assert0[(AF_INET == PF_INET) ? 1 : -1];
	char assert1[(AF_INET6 == PF_INET6) ? 1 : -1];
};

@interface AFNetworkSocket ()
@property (assign, nonatomic) CFSocketNativeHandle socketNative;
@property (copy, nonatomic) NSSet *options;
@property (assign, nonatomic) NSUInteger socketFlags;

@property (retain, nonatomic) AFNetworkSchedule *schedule;
- (void)_resumeSources;
@end

@interface AFNetworkSocket ()
- (void)_readCallback;
- (void)_acceptCallback;
- (void)_dataCallback;
@end

@implementation AFNetworkSocket

@dynamic delegate;

@synthesize socketNative=_socketNative;
@synthesize options=_options;
@synthesize socketFlags=_socketFlags;
@synthesize schedule=_schedule;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_socketNative = -1;
	
	return self;
}

- (id)initWithSocketSignature:(CFSocketSignature const *)signature options:(NSSet *)options {
	self = [self init];
	if (self == nil) return nil;
	
	_signature = malloc(sizeof(CFSocketSignature));
	memcpy(_signature, signature, sizeof(CFSocketSignature));
	CFRetain(_signature->address);
	
	_options = [options copy];
	
	return self;
}

- (id)initWithNativeHandle:(CFSocketNativeHandle)socketNative {
	self = [self init];
	if (self == nil) return nil;
	
	_socketNative = socketNative;
	
	return self;
}

- (void)dealloc {
	if (_signature != NULL) {
		if (_signature->address != NULL) {
			CFRelease(_signature->address);
		}
		free(_signature);
	}
	
	[_options release];
	
	[_schedule release];
	
	if (_sources._runLoop._fileDescriptor != NULL) {
		CFRelease(_sources._runLoop._fileDescriptor);
	}
	if (_sources._runLoop._source != NULL) {
		CFRelease(_sources._runLoop._source);
	}
	
	if (_sources._dispatchSource != NULL) {
		dispatch_release(_sources._dispatchSource);
	}
	
	[super dealloc];
}

- (BOOL)_createSocketNativeIfNeeded:(NSError **)errorRef {
	if (_socketNative >= 0) {
		return YES;
	}
	
	CFSocketSignature *signature = _signature;
	NSParameterAssert(signature != NULL);
	
	CFSocketNativeHandle newSocketNative = socket(signature->protocolFamily, signature->socketType, signature->protocol);
	if (newSocketNative == -1) {
		if (errorRef != NULL) {
			*errorRef = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
		}
		return NO;
	}
	
	BOOL configure = [self _configureSocketNativePreBind:newSocketNative error:errorRef];
	if (!configure) {
		close(newSocketNative);
		return NO;
	}
	
	BOOL bind = [self _bindSocket:newSocketNative error:errorRef];
	if (!bind) {
		close(newSocketNative);
		return NO;
	}
	
	/*
		Note
		
		this may fail for socket types that aren't connection-oriented
		
		hence we ignore the return value (and the value of errno) as in the CFSocket implementation of CFSocketSetAddress
	 */
	int listenError = listen(newSocketNative, 256);
	if (listenError != -1) {
		self.socketFlags = (self.socketFlags | _AFNetworkSocketFlagsListen);
	}
	
	self.socketNative = newSocketNative;
	return YES;
}

- (BOOL)_configureSocketNativePreBind:(CFSocketNativeHandle)socketNative error:(NSError **)errorRef {
	NSMutableSet *options = [NSMutableSet setWithSet:self.options];
	
#if DEBUGFULL
	int reuseAddress = 1;
	AFNetworkSocketOption *reuseAddressOption = [[[AFNetworkSocketOption alloc] initWithLevel:SOL_SOCKET option:SO_REUSEADDR data:[NSData dataWithBytes:&reuseAddress length:sizeof(reuseAddress)]] autorelease];
	[options addObject:reuseAddressOption];
#endif /* DEBUGFULL */
	
	for (AFNetworkSocketOption *currentOption in options) {
		NSData *currentValue = currentOption.data;
		int setOption = setsockopt(socketNative, currentOption.level, currentOption.option, currentValue.bytes, (socklen_t)currentValue.length);
		if (setOption != 0) {
			if (errorRef != NULL) {
				*errorRef = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
			}
			return NO;
		}
	}
	
	return YES;
}

- (BOOL)_bindSocket:(CFSocketNativeHandle)socketNative error:(NSError **)errorRef {
	CFDataRef addressData = _signature->address;
	
	int bindError = af_bind(socketNative, (struct sockaddr_storage const *)CFDataGetBytePtr(addressData));
	if (bindError != 0) {
		int underlyingErrorCode = errno;
		NSError *underlyingError = [NSError errorWithDomain:NSPOSIXErrorDomain code:underlyingErrorCode userInfo:nil];
		
		if (errorRef != NULL) {
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
									   NSLocalizedStringFromTableInBundle(@"Couldn\u2019t open socket", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkSocket couldn't open error description"), NSLocalizedDescriptionKey,
									   underlyingError, NSUnderlyingErrorKey,
									   nil];
			*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:errorCode userInfo:errorInfo];
		}
		return NO;
	}
	
	return YES;
}

- (BOOL)open:(NSError **)errorRef {
	BOOL open = [self _actuallyOpenIfNeeded:errorRef];
	if (!open) {
		return NO;
	}
	
	[self.delegate networkLayerDidOpen:self];
	
	return YES;
}

- (BOOL)_actuallyOpenIfNeeded:(NSError **)errorRef {
	NSParameterAssert([self _isScheduled]);
	
	NSParameterAssert(self.delegate != nil);
	
	if ([self isOpen]) {
		return YES;
	}
	
	BOOL createSocket = [self _createSocketNativeIfNeeded:errorRef];
	if (!createSocket) {
		return NO;
	}
	
	[self _assertDelegateIsAppropriateForSocketType];
	
	self.socketFlags = (self.socketFlags | _AFNetworkSocketFlagsDidOpen);
	
	[self _resumeSources];
	
	return YES;
}

- (BOOL)isOpen {
	return ((self.socketFlags & (_AFNetworkSocketFlagsDidOpen | _AFNetworkSocketFlagsDidClose)) == _AFNetworkSocketFlagsDidOpen);
}

- (void)close {
	if ([self isClosed]) {
		return;
	}
	self.socketFlags = (self.socketFlags | _AFNetworkSocketFlagsDidClose);
	
	[self _invalidateSources];
	[self _actuallyCloseIfNeeded];
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidClose:)]) {
		[self.delegate networkLayerDidClose:self];
	}
}

- (void)_actuallyCloseIfNeeded {
	if (_sources._dispatchSource != NULL) {
		// Note: dispatch sources are closed in the cancellation handler which run after any current activity
		return;
	}
	
	CFSocketNativeHandle socketNative = self.socketNative;
	if (socketNative == -1) {
		return;
	}
	
	[self _actuallyClose:socketNative];
}

- (void)_actuallyClose:(CFSocketNativeHandle)socketNative {
	if (socketNative >= 0) {
		__unused int closeError = close(socketNative);
#warning look into whether we can receive EINTR on OS X and whether we need a threadsafe close pattern that doesn't use an EINTR loop, libdispatch uses dup2 to /dev/null, perhaps that is to handle this issue?
	}
}

- (BOOL)isClosed {
	return ((self.socketFlags & _AFNetworkSocketFlagsDidClose) == _AFNetworkSocketFlagsDidClose);
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@"{\n"];
	
	NSData *localAddress = self.localAddress;
	if (localAddress != NULL) {
		[description appendFormat:@"\tAddress: %@\n", AFNetworkSocketAddressToPresentation(localAddress, NULL)];
		[description appendFormat:@"\tPort: %ld\n", (unsigned long)af_sockaddr_in_read_port((struct sockaddr_storage const *)CFDataGetBytePtr((CFDataRef)localAddress))];
	}
	
	[description appendString:@"}"];
	
	return description;
}

- (void)_assertDelegateIsAppropriateForSocketType {
	CFSocketNativeHandle socketNative = self.socketNative;
	NSParameterAssert(socketNative != -1);
	
	int socketType = 0;
	socklen_t socketTypeSize = sizeof(socketType);
	int socketTypeError = getsockopt(socketNative, SOL_SOCKET, SO_TYPE, &socketType, &socketTypeSize);
	NSParameterAssert(socketTypeError != -1);
	
	SEL requiredSelector = NULL;
	switch (socketType) {
		case SOCK_STREAM:
		{
			requiredSelector = @selector(networkLayer:didReceiveConnection:);
			break;
		}
		case SOCK_DGRAM:
		{
			requiredSelector = @selector(networkLayer:didReceiveDatagram:);
			break;
		}
	}
	NSParameterAssert(requiredSelector != NULL);
	
	id <AFNetworkSocketDelegate> delegate = self.delegate;
	NSParameterAssert(delegate != nil);
	
	NSParameterAssert([delegate respondsToSelector:requiredSelector]);
}

- (BOOL)_isScheduled {
	return (self.schedule != nil);
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(![self _isScheduled]);
	
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInRunLoop:runLoop forMode:mode];
	self.schedule = newSchedule;
}

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	NSParameterAssert(![self _isScheduled]);
	
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInQueue:queue];
	self.schedule = newSchedule;
}

static void _AFNetworkSocketFileDescriptorEnableCallbacks(CFFileDescriptorRef fileDescriptor) {
	CFFileDescriptorEnableCallBacks(fileDescriptor, kCFFileDescriptorReadCallBack);
}

static void _AFNetworkSocketFileDescriptorCallBack(CFFileDescriptorRef fileDescriptor, CFOptionFlags callBackTypes, void *info) {
	AFNetworkSocket *self = info;
	
	@autoreleasepool {
		[self _readCallback];
	}
	
	_AFNetworkSocketFileDescriptorEnableCallbacks(fileDescriptor);
}

- (void)_resumeSources {
	AFNetworkSchedule *schedule = self.schedule;
	NSParameterAssert(schedule != nil);
	
	if (schedule->_runLoop != nil) {
		NSRunLoop *runLoop = schedule->_runLoop;
		
		CFFileDescriptorContext context = {
			.info = self,
		};
		CFFileDescriptorRef newFileDescriptor = CFFileDescriptorCreate(kCFAllocatorDefault, self.socketNative, false, _AFNetworkSocketFileDescriptorCallBack, &context);
		_sources._runLoop._fileDescriptor = newFileDescriptor;
		
		CFRunLoopSourceRef newRunLoopSource = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, newFileDescriptor, 0);
		_sources._runLoop._source = newRunLoopSource;
		
		CFRunLoopAddSource([runLoop getCFRunLoop], newRunLoopSource, (CFStringRef)schedule->_runLoopMode);
		
		_AFNetworkSocketFileDescriptorEnableCallbacks(newFileDescriptor);
	}
	else if (schedule->_dispatchQueue != NULL) {
		dispatch_queue_t dispatchQueue = schedule->_dispatchQueue;
		
		CFSocketNativeHandle socketNative = self.socketNative;
		
		dispatch_source_t newSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, socketNative, 0, dispatchQueue);
		dispatch_source_set_event_handler(newSource, ^ {
			[self _readCallback];
		});
		dispatch_source_set_cancel_handler(newSource, ^ {
			[self _actuallyClose:socketNative];
		});
		_sources._dispatchSource = newSource;
		
		dispatch_resume(newSource);
	}
	else {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"unsupported schedule environment, cannot resume socket" userInfo:nil];
	}
}

- (BOOL)_isValid {
	return (_sources._runLoop._source != NULL || _sources._dispatchSource != NULL);
}

- (void)_invalidateSources {
	if (![self _isValid]) {
		return;
	}
	
	if (_sources._runLoop._source != NULL) {
		CFRunLoopSourceRef runLoopSource = (CFRunLoopSourceRef)_sources._runLoop._source;
		CFRunLoopSourceInvalidate(runLoopSource);
	}
	else if (_sources._dispatchSource != NULL) {
		dispatch_source_t dispatchSource = _sources._dispatchSource;
		dispatch_source_cancel(dispatchSource);
	}
	else {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"unsupported schedule environment, cannot invalidate socket" userInfo:nil];
	}
}

- (void)_readCallback {
	if ((self.socketFlags & _AFNetworkSocketFlagsListen) == _AFNetworkSocketFlagsListen) {
		[self _acceptCallback];
		return;
	}
	
	[self _dataCallback];
}

- (void)_acceptCallback {
	struct sockaddr *newSocketAddress = alloca(SOCK_MAXADDRLEN);
	socklen_t newSocketAddressLength = sizeof(newSocketAddress);
	
TryAccept:;
	CFSocketNativeHandle newSocketNative = accept(self.socketNative, newSocketAddress, &newSocketAddressLength);
	if (newSocketNative == -1) {
		if (errno == EINTR) {
			goto TryAccept;
		}
		
		switch (errno) {
			case EBADF: /* socket is not a valid file descriptor. */
				break;
			case ECONNABORTED: /* The connection to socket has been aborted. */
				break;
			case EFAULT: /* The address parameter is not in a writable part of the user address space. */
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
	
	__unused NSData *newSocketAddressData = [NSData dataWithBytes:&newSocketAddress length:newSocketAddressLength];
	
	AFNetworkSocket *newSocket = [self _socketForSocketNative:newSocketNative];
	if (newSocket == nil) {
		close(newSocketNative);
		return;
	}
	
	[self.delegate networkLayer:self didReceiveConnection:newSocket];
}

- (void)_dataCallback {
	CFSocketNativeHandle socketNative = self.socketNative;
	
	struct sockaddr_storage from = {};
	
TryRecv:;
	
	int availableData = 0;
	socklen_t availableDataSize = sizeof(availableData);
	int availableDataError = getsockopt(socketNative, SOL_SOCKET, SO_NREAD, &availableData, &availableDataSize);
	if (availableDataError != 0) {
		return;
	}
	
	NSMutableData *buffer = [NSMutableData dataWithLength:availableData];
	
	struct iovec storageArea = {
		.iov_base = [buffer mutableBytes],
		.iov_len = [buffer length],
	};
	
	uint8_t ancillary[1024];
	
	struct msghdr message = {
		.msg_name = &from,
		.msg_namelen = sizeof(from),
		.msg_iov = &storageArea,
		.msg_iovlen = 1,
		.msg_control = &ancillary,
		.msg_controllen = sizeof(ancillary),
		.msg_flags = 0,
	};
	ssize_t size = recvmsg(socketNative, &message, 0);
	
	if (size == 0) {
		return;
	}
	else if (size == -1) {
		if (errno == EINTR) {
			goto TryRecv;
		}
		return;
	}

	NSMutableSet *metadata = [NSMutableSet set];

	// Read Metadata
	do {
		if (message.msg_controllen < sizeof(struct cmsghdr)) {
			break;
		}
		
		if ((message.msg_flags & MSG_CTRUNC) == MSG_CTRUNC) {
			break;
		}
		
		for (struct cmsghdr *controlMessageHeader = CMSG_FIRSTHDR(&message); controlMessageHeader != NULL; controlMessageHeader = CMSG_NXTHDR(&message, controlMessageHeader)) {
			NSData *value = [NSData dataWithBytes:CMSG_DATA(controlMessageHeader) length:controlMessageHeader->cmsg_len - sizeof(*controlMessageHeader)];
			AFNetworkSocketOption *option = [[[AFNetworkSocketOption alloc] initWithLevel:controlMessageHeader->cmsg_level option:controlMessageHeader->cmsg_type data:value] autorelease];
			[metadata addObject:option];
		}
	} while (0);
	
	NSData *senderAddress = [NSData dataWithBytes:&from length:message.msg_namelen];
	
	[buffer setLength:storageArea.iov_len];
	
	AFNetworkDatagram *datagram = [[[AFNetworkDatagram alloc] initWithSenderAddress:senderAddress data:buffer metadata:metadata] autorelease];
	
	[self.delegate networkLayer:self didReceiveDatagram:datagram];
}

- (AFNetworkSocket *)_socketForSocketNative:(CFSocketNativeHandle)socketNative {
	AFNetworkSocket *newSocket = [[[AFNetworkSocket alloc] initWithNativeHandle:socketNative] autorelease];
	newSocket.schedule = self.schedule;
	return newSocket;
}

- (NSData *)localAddress {
	return [self _address:getsockname];
}

- (NSData *)peerAddress {
	return [self _address:getpeername];
}

- (NSData *)_address:(int (*)(int, struct sockaddr *restrict, socklen_t *restrict))function {
	NSParameterAssert(function != NULL);
	
	CFSocketNativeHandle socketNative = self.socketNative;
	
	struct sockaddr_storage address = {};
	socklen_t addressSize = sizeof(address);
	int addressError = function(socketNative, (struct sockaddr *)&address, &addressSize);
	if (addressError != 0) {
		return nil;
	}
	
	return [NSData dataWithBytes:&address length:addressSize];
}

@end
