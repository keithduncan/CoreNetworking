//
//  AFNetworkTransport.m
//	Amber
//
//	Originally based on AsyncSocket <http://code.google.com/p/cocoaasyncsocket/>
//	Although the class is now much departed from the original codebase.
//
//  Created by Keith Duncan
//  Copyright 2008. All rights reserved.
//

#import "AFNetworkTransport.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif /* TARGET_OS_IPHONE */
#import <objc/runtime.h>
#import <objc/message.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <sys/errno.h>
#import <netdb.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "AFNetworkSocket.h"
#import "AFNetworkStreamQueue.h"
#import "AFNetworkPacketQueue.h"
#import "AFNetworkPacketRead.h"
#import "AFNetworkPacketWrite.h"

#import "AFNetwork-Constants.h"
#import "AFNetwork-Functions.h"
#import "AFNetwork-Macros.h"

typedef AFNETWORK_OPTIONS(NSUInteger, AFNetworkTransportStreamFlags) {
	_AFNetworkTransportStreamFlagsDidOpen	= 1UL << 0,
	_AFNetworkTransportStreamFlagsDidClose	= 1UL << 1,
};

typedef AFNETWORK_OPTIONS(NSUInteger, AFNetworkTransportConnectionFlags) {
	_AFNetworkTransportConnectionFlagsDidOpen		= 1UL << 0, // connection has been established
	_AFNetworkTransportConnectionFlagsWillStartTLS	= 1UL << 1,
	_AFNetworkTransportConnectionFlagsDidStartTLS	= 1UL << 2,
	_AFNetworkTransportConnectionFlagsDidClose		= 1UL << 4, // the stream has disconnected
};

@interface AFNetworkTransport ()
@property (readwrite, retain, nonatomic) AFNetworkStreamQueue *writeStream;
@property (assign, nonatomic) NSUInteger writeFlags;

@property (readwrite, retain, nonatomic) AFNetworkStreamQueue *readStream;
@property (assign, nonatomic) NSUInteger readFlags;

@property (assign, nonatomic) NSUInteger connectionFlags;
@end

// Note: the selectors aren't all actually implemented, some are added dynamically
@interface AFNetworkTransport (Delegate) <AFNetworkStreamQueueDelegate>
@end

@interface AFNetworkTransport (Streams)
- (void)_configureWithWriteStream:(NSOutputStream *)writeStream readStream:(NSInputStream *)readStream;
- (void)_suspendStreamPacketQueues;
- (void)_resumeStreamPacketQueues;
- (void)_streamDidOpen;
- (void)_streamDidStartTLS;
@end

#pragma mark -

@implementation AFNetworkTransport

@dynamic delegate;

@synthesize writeStream=_writeStream, writeFlags=_writeFlags;
@synthesize readStream=_readStream, readFlags=_readFlags;

@synthesize connectionFlags=_connectionFlags;

+ (Class)lowerLayerClass {
	return [AFNetworkSocket class];
}

- (id)initWithLowerLayer:(id <AFNetworkTransportLayer>)layer {
	NSParameterAssert([layer isKindOfClass:[AFNetworkSocket class]]);
	AFNetworkSocket *networkSocket = (AFNetworkSocket *)layer;
	
	self = [super initWithLowerLayer:layer];
	if (self == nil) return nil;
	
	CFSocketNativeHandle socketNative = networkSocket->_socketNative;
	networkSocket->_socketNative = -1;
	
	/* 
		Note 
		
		ensure the socket's claim on the file descriptor is relinquished
	 */
	[networkSocket setDelegate:nil];
	[networkSocket close];
	
	CFWriteStreamRef writeStream = NULL;
	CFReadStreamRef readStream = NULL;
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, socketNative, &readStream, &writeStream);
	
	if (writeStream == NULL || readStream == NULL) {
		close(socketNative);
		
		if (writeStream != NULL) {
			CFRelease(writeStream);
		}
		
		if (readStream != NULL) {
			CFRelease(readStream);
		}
		
		[self release];
		return nil;
	}
	
	CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	
	[self _configureWithWriteStream:(id)writeStream readStream:(id)readStream];
	
	CFRelease(writeStream);
	CFRelease(readStream);
	
	return self;
}

- (id <AFNetworkTransportLayer>)_initWithHostSignature:(AFNetworkHostSignature *)signature {
	self = [self init];
	if (self == nil) return nil;
	
	memcpy(&_signature._host, signature, sizeof(AFNetworkHostSignature));
	
	CFHostRef *host = &_signature._host.host;
	*host = (CFHostRef)NSMakeCollectable(CFRetain(signature->host));
	
	CFWriteStreamRef writeStream = NULL;
	CFReadStreamRef readStream = NULL;
	CFStreamCreatePairWithSocketToCFHost(kCFAllocatorDefault, *host, _signature._host.transport.port, &readStream, &writeStream);
	
	if (writeStream == NULL || readStream == NULL) {
		if (writeStream != NULL) {
			CFRelease(writeStream);
		}
		
		if (readStream != NULL) {
			CFRelease(readStream);
		}
		
		[self release];
		return nil;
	}
	
	[self _configureWithWriteStream:(id)writeStream readStream:(id)readStream];
	
	CFRelease(writeStream);
	CFRelease(readStream);
	
	return self;
}

- (id <AFNetworkTransportLayer>)_initWithServiceSignature:(AFNetworkServiceSignature *)signature {
	self = [self init];
	if (self == nil) return nil;
	
	CFNetServiceRef *service = &_signature._service.service;
	*service = (CFNetServiceRef)CFMakeCollectable(CFNetServiceCreateCopy(kCFAllocatorDefault, *(CFNetServiceRef *)signature));
	
	CFWriteStreamRef writeStream = NULL;
	CFReadStreamRef readStream = NULL;
	CFStreamCreatePairWithSocketToNetService(kCFAllocatorDefault, *service, &readStream, &writeStream);
	
	if (writeStream == NULL || readStream == NULL) {
		if (writeStream != NULL) {
			CFRelease(writeStream);
		}
		
		if (readStream != NULL) {
			CFRelease(readStream);
		}
		
		[self release];
		return nil;
	}
	
	[self _configureWithWriteStream:(id)writeStream readStream:(id)readStream];
	
	CFRelease(writeStream);
	CFRelease(readStream);
	
	return self;
}

- (AFNetworkLayer *)initWithTransportSignature:(AFNetworkSignature)signature {
	CFTypeID type = CFGetTypeID(*(CFTypeRef *)*(void **)&signature);
	
	if (type == CFHostGetTypeID()) {
		return [self _initWithHostSignature:signature._host];
	}
	else if (type == CFNetServiceGetTypeID()) {
		return [self _initWithServiceSignature:signature._service];
	}
	
	@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s, unrecognised signature", __PRETTY_FUNCTION__] userInfo:nil];
	return nil;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	CFTypeRef *peer = (CFTypeRef *)&_signature._host.host;
	if (*peer != NULL) {
		CFRelease(*peer);
		*peer = NULL;
	}
	
	[_writeStream release];
	[_readStream release];
	
	[super dealloc];
}

- (NSData *)localAddress {
	NSParameterAssert([self isOpen]);
	
	CFSocketNativeHandle socket = 0;
	NSData *socketData = [[self readStream] streamPropertyForKey:(id)kCFStreamPropertySocketNativeHandle];
	NSParameterAssert(socketData != nil && [socketData length] > 0 && sizeof(CFSocketNativeHandle) <= [socketData length]);
	[socketData getBytes:&socket length:[socketData length]];
	
	socklen_t socketAddressLength = SOCK_MAXADDRLEN;
	struct sockaddr_storage *socketAddress = alloca(socketAddressLength);
	int getsocketnameError = getsockname(socket, (struct sockaddr *)socketAddress, &socketAddressLength);
	if (getsocketnameError != 0) {
		return nil;
	}
	
	return [NSData dataWithBytes:socketAddress length:socketAddressLength];
}

- (NSData *)peerAddress {
	NSParameterAssert([self isOpen]);
	
	return nil;
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@" {\n"];
	
	[description appendFormat:@"\tOpened: %@, Closed: %@\n", ([self isOpen] ? @"YES" : @"NO"), ([self isClosed] ? @"YES" : @"NO")];
	
	[description appendFormat:@"\tWrite Stream: %@", [self.writeStream description]];
	[description appendFormat:@"\tRead Stream: %@", [self.readStream description]];
	
	[description appendString:@"}"];
	
	return description;
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	[self.writeStream scheduleInRunLoop:runLoop forMode:mode];
	[self.readStream scheduleInRunLoop:runLoop forMode:mode];
}

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	[self.writeStream scheduleInQueue:queue];
	[self.readStream scheduleInQueue:queue];
}

#pragma mark - Connection

- (void)open {
	NSParameterAssert(self.delegate != nil);
	
	if ([self isOpen]) {
		[self.delegate networkLayerDidOpen:self];
		return;
	}
	
	[self _suspendStreamPacketQueues];
	
	[self.writeStream open];
	[self.readStream open];
}

- (BOOL)isOpen {
	return ((self.connectionFlags & _AFNetworkTransportConnectionFlagsDidOpen) == _AFNetworkTransportConnectionFlagsDidOpen);
}

- (void)close {
	if ([self isClosed]) {
		[self.delegate networkLayerDidClose:self];
		return;
	}
	
	if (self.writeStream != nil) {
		[self.writeStream close];
		[self setWriteFlags:([self writeFlags] | _AFNetworkTransportStreamFlagsDidClose)];
	}
	
	if (self.readStream != nil) {
		[self.readStream close];
		[self setReadFlags:([self readFlags] | _AFNetworkTransportStreamFlagsDidClose)];
	}
	
	// Note: set this before the delegation so that the object can be released
	self.connectionFlags = (self.connectionFlags | _AFNetworkTransportConnectionFlagsDidClose);
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidClose:)]) {
		[self.delegate networkLayerDidClose:self];
	}
}

- (BOOL)isClosed {
	return ((self.connectionFlags & _AFNetworkTransportConnectionFlagsDidClose) == _AFNetworkTransportConnectionFlagsDidClose);
}

- (BOOL)startTLS:(NSDictionary *)options error:(NSError **)errorRef {
	if ((self.connectionFlags & _AFNetworkTransportConnectionFlagsWillStartTLS) == _AFNetworkTransportConnectionFlagsWillStartTLS) {
		return YES;
	}
	self.connectionFlags = (self.connectionFlags | _AFNetworkTransportConnectionFlagsWillStartTLS);
	
	[self _suspendStreamPacketQueues];
	
	/*
		Note
		
		this allows for a nil options dictionary, but non-nil streamProperty
	 */
	NSDictionary *streamProperty = [NSDictionary dictionaryWithDictionary:options];
	
	AFNetworkStreamQueue *stream = (self.writeStream ? : self.readStream);
	BOOL startTLS = [stream setStreamProperty:streamProperty forKey:(id)kCFStreamPropertySSLSettings];
	if (!startTLS) {
		if (errorRef != NULL) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  NSLocalizedStringFromTableInBundle(@"Your connection couldn\u2019t be secured", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkTransport couldn't start TLS error description"), NSLocalizedDescriptionKey,
									  nil];
			*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkTransportErrorTLS userInfo:userInfo];
		}
		return NO;
	}
	
	return YES;
}

- (BOOL)isSecure {
	[self doesNotRecognizeSelector:_cmd];
	return NO;
}

#pragma mark -

- (void)networkStream:(AFNetworkStreamQueue *)stream didReceiveEvent:(NSStreamEvent)event {
	NSParameterAssert(stream == self.writeStream || stream == self.readStream);
	
	switch (event) {
		case NSStreamEventOpenCompleted:
		{
			if (stream == self.writeStream) {
				[self setWriteFlags:([self writeFlags] | _AFNetworkTransportStreamFlagsDidOpen)];
			}
			else if (stream == self.readStream) {
				[self setReadFlags:([self readFlags] | _AFNetworkTransportStreamFlagsDidOpen)];
			}
			
			[self _streamDidOpen];
			break;
		}
		case NSStreamEventHasBytesAvailable:
		case NSStreamEventHasSpaceAvailable:
		{
			if (((self.connectionFlags & _AFNetworkTransportConnectionFlagsWillStartTLS) != _AFNetworkTransportConnectionFlagsWillStartTLS) || ((self.connectionFlags & _AFNetworkTransportConnectionFlagsDidStartTLS) == _AFNetworkTransportConnectionFlagsDidStartTLS)) {
				break;
			}
			
			[self _streamDidStartTLS];
			break;
		}
		case NSStreamEventEndEncountered:
		{
			if (stream == self.writeStream) {
				self.writeFlags = (self.writeFlags | _AFNetworkTransportStreamFlagsDidClose);
			}
			else if (stream == self.readStream) {
				self.readFlags = (self.readFlags | _AFNetworkTransportStreamFlagsDidClose);
			}
			
			[self close];
			break;
		}
		default:
		{
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"unknown stream event %lu", event] userInfo:nil];
			break;
		}
	}
}

- (void)networkStream:(AFNetworkStreamQueue *)stream didReceiveError:(NSError *)error {
	NSError *newError = AFNetworkStreamPrepareDisplayError(stream, error);
	[self.delegate networkLayer:self didReceiveError:newError];
}

#pragma mark Writing

- (void)performWrite:(id)buffer withTimeout:(NSTimeInterval)timeout context:(void *)context {
	NSParameterAssert(buffer != nil);
	
	AFNetworkPacketWrite *packet = nil;
	if (![buffer isKindOfClass:[AFNetworkPacket class]]) {
		packet = [[[AFNetworkPacketWrite alloc] initWithData:buffer] autorelease];
	}
	else {
		packet = buffer;
	}
	
	packet->_idleTimeout = timeout;
	packet->_context = context;
	
	[self.writeStream enqueuePacket:packet];
}

#pragma mark Reading

- (void)performRead:(id)terminator withTimeout:(NSTimeInterval)timeout context:(void *)context {
	NSParameterAssert(terminator != nil);
	
	AFNetworkPacketRead *packet = nil;
	if (![terminator isKindOfClass:[AFNetworkPacket class]]) {
		packet = [[[AFNetworkPacketRead alloc] initWithTerminator:terminator] autorelease];
	}
	else {
		packet = terminator;
	}
	
	packet->_idleTimeout = timeout;
	packet->_context = context;
	
	[self.readStream enqueuePacket:packet];
}

@end

#pragma mark -

@implementation AFNetworkTransport (Streams)

- (void)_configureWithWriteStream:(NSOutputStream *)writeStream readStream:(NSInputStream *)readStream {
	if (writeStream != nil) {
		AFNetworkStreamQueue *stream = [[(AFNetworkStreamQueue *)[AFNetworkStreamQueue alloc] initWithStream:writeStream] autorelease];
		stream.delegate = self;
		self.writeStream = stream;
	}
	
	if (readStream != nil) {
		AFNetworkStreamQueue *stream = [[(AFNetworkStreamQueue *)[AFNetworkStreamQueue alloc] initWithStream:readStream] autorelease];
		stream.delegate = self;
		self.readStream = stream;
	}
}

- (void)_suspendStreamPacketQueues {
	[self.writeStream suspendPacketQueue];
	[self.readStream suspendPacketQueue];
}

- (void)_resumeStreamPacketQueues {
	[self.writeStream resumePacketQueue];
	[self.readStream resumePacketQueue];
}

- (void)_streamDidOpen {
	if ((self.connectionFlags & _AFNetworkTransportConnectionFlagsDidOpen) == _AFNetworkTransportConnectionFlagsDidOpen) {
		return;
	}
	
	if (self.writeStream != nil && ((self.writeFlags & _AFNetworkTransportStreamFlagsDidOpen) != _AFNetworkTransportStreamFlagsDidOpen)) {
		return;
	}
	if (self.readStream != nil && ((self.readFlags & _AFNetworkTransportStreamFlagsDidOpen) != _AFNetworkTransportStreamFlagsDidOpen)) {
		return;
	}
	self.connectionFlags = (self.connectionFlags | _AFNetworkTransportConnectionFlagsDidOpen);
	
	[self _resumeStreamPacketQueues];
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidOpen:)]) {
		[self.delegate networkLayerDidOpen:self];
	}
}

- (void)_streamDidStartTLS {
	if ((self.connectionFlags & _AFNetworkTransportConnectionFlagsDidStartTLS) == _AFNetworkTransportConnectionFlagsDidStartTLS) {
		return;
	}
	self.connectionFlags = (self.connectionFlags | _AFNetworkTransportConnectionFlagsDidStartTLS);
	
	[self _resumeStreamPacketQueues];
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidStartTLS:)]) {
		[self.delegate networkLayerDidStartTLS:self];
	}
}

- (void)networkStream:(AFNetworkStreamQueue *)networkStream didTransfer:(AFNetworkPacket *)packet bytesTransferred:(NSInteger)bytesTransferred totalBytesTransferred:(NSInteger)totalBytesTransferred totalBytesExpectedToTransfer:(NSInteger)totalBytesExpectedToTransfer {
	SEL delegateSelector = NULL;
	if (networkStream == self.writeStream) {
		delegateSelector = @selector(networkTransport:didWritePartialDataOfLength:totalBytesWritten:totalBytesExpectedToWrite:context:);
	}
	else if (networkStream == self.readStream) {
		delegateSelector = @selector(networkTransport:didReadPartialDataOfLength:totalBytesRead:totalBytesExpectedToRead:context:);
	}
	NSCParameterAssert(delegateSelector != NULL);
	
	if (![self.delegate respondsToSelector:delegateSelector]) {
		return;
	}
	((void (*)(id, SEL, id, NSUInteger, NSUInteger, NSUInteger, void *))objc_msgSend)(self.delegate, delegateSelector, self, bytesTransferred, totalBytesTransferred, totalBytesExpectedToTransfer, packet.context);
}

- (void)networkStream:(AFNetworkStreamQueue *)networkStream didDequeuePacket:(AFNetworkPacket *)networkPacket {
	SEL delegateSelector = NULL;
	if (networkStream == self.writeStream) {
		delegateSelector = @selector(networkLayer:didWrite:context:);
	}
	else if (networkStream == self.readStream) {
		delegateSelector = @selector(networkLayer:didRead:context:);
	}
	NSCParameterAssert(delegateSelector != NULL);
	
	((void (*)(id, SEL, id, id, void *))objc_msgSend)(self.delegate, delegateSelector, self, networkPacket, networkPacket.context);
}

@end
