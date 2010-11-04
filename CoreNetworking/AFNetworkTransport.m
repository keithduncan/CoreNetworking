//
//  AFNetworkTransport.m
//	Amber
//
//	Originally based on AsyncSocket http://code.google.com/p/cocoaasyncsocket/
//	Although the class is now much departed from the original codebase.
//
//  Created by Keith Duncan
//  Copyright 2008. All rights reserved.
//

#import "AFNetworkTransport.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif
#import <objc/runtime.h>
#import <objc/message.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <sys/errno.h>
#import <netdb.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "AFNetworkSocket.h"
#import "AFNetworkConstants.h"
#import "AFNetworkFunctions.h"
#import "AFNetworkStream.h"
#import "AFNetworkPacketQueue.h"
#import "AFNetworkPacketRead.h"
#import "AFNetworkPacketWrite.h"

enum {
	_kConnectionDidOpen			= 1UL << 0, // connection has been established
	_kConnectionWillStartTLS	= 1UL << 1,
	_kConnectionDidStartTLS		= 1UL << 2,
	_kConnectionCloseSoon		= 1UL << 3, // disconnect as soon as nothing is queued
	_kConnectionDidClose		= 1UL << 4, // the stream has disconnected
};
typedef NSUInteger AFSocketConnectionFlags;

enum {
	_kStreamDidOpen			= 1UL << 0,
	_kStreamDidClose		= 1UL << 1,
};
typedef NSUInteger AFSocketConnectionStreamFlags;

@interface AFNetworkTransport ()
@property (readonly) AFNetworkStream *writeStream;
@property (readonly) AFNetworkStream *readStream;
@end

// Note: the selectors aren't all actually implemented, some are added dynamically
@interface AFNetworkTransport (Delegate) <AFNetworkStreamDelegate>
@end

@interface AFNetworkTransport (Streams)
- (void)_configureWriteStream:(NSOutputStream *)writeStream readStream:(NSInputStream *)readStream;
- (void)_streamDidOpen;
- (void)_streamDidStartTLS;
@end

#pragma mark -

@implementation AFNetworkTransport

@dynamic delegate;
@synthesize writeStream=_writeStream, readStream=_readStream;

+ (Class)lowerLayer {
	return [AFNetworkSocket class];
}

- (id)initWithLowerLayer:(id <AFNetworkTransportLayer>)layer {
	NSParameterAssert([layer isKindOfClass:[AFNetworkSocket class]]);
	
	self = [super initWithLowerLayer:layer];
	if (self == nil) return nil;
	
	AFNetworkSocket *networkSocket = (AFNetworkSocket *)layer;
	CFSocketRef socket = (CFSocketRef)[networkSocket socket];
	
	BOOL shouldCloseUnderlyingSocket = ((CFSocketGetSocketFlags(socket) & kCFSocketCloseOnInvalidate) == kCFSocketCloseOnInvalidate);
	if (shouldCloseUnderlyingSocket) CFSocketSetSocketFlags(socket, CFSocketGetSocketFlags(socket) & ~kCFSocketCloseOnInvalidate);
	
	CFDataRef peer = (CFDataRef)[networkSocket peer];
	_signature._host.host = (CFHostRef)CFMakeCollectable(CFRetain(peer));
	
	CFSocketNativeHandle nativeSocket = CFSocketGetNative(socket);
	CFSocketInvalidate(socket); // Note: the CFSocket must be invalidated for the CFStreams to capture the events
	
	CFWriteStreamRef writeStream;
	CFReadStreamRef readStream;
	
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocket, &readStream, &writeStream);
	
	// Note: ensure this is done in the same method as setting the socket options to essentially balance a retain/release on the native socket
	if (shouldCloseUnderlyingSocket) {
		CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
		CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	}
	[self _configureWriteStream:(id)writeStream readStream:(id)readStream];
	
	CFRelease(writeStream);
	CFRelease(readStream);
	
	return self;
}

- (id <AFNetworkConnectionLayer>)_initWithHostSignature:(AFNetworkHostSignature *)signature {
	self = [self init];
	if (self == nil) return nil;
	
	memcpy(&_signature._host, signature, sizeof(AFNetworkHostSignature));
	
	CFHostRef *host = &_signature._host.host;
	*host = (CFHostRef)NSMakeCollectable(CFRetain(signature->host));
	
	CFWriteStreamRef writeStream;
	CFReadStreamRef readStream;
	
	CFStreamCreatePairWithSocketToCFHost(kCFAllocatorDefault, *host, _signature._host.transport.port, &readStream, &writeStream);
	
	[self _configureWriteStream:(id)writeStream readStream:(id)readStream];
	
	CFRelease(writeStream);
	CFRelease(readStream);
	
	return self;
}

- (id <AFNetworkConnectionLayer>)_initWithServiceSignature:(AFNetworkServiceSignature *)signature {
	self = [self init];
	if (self == nil) return nil;
	
	CFNetServiceRef *service = &_signature._service.service;
	*service = (CFNetServiceRef)CFMakeCollectable(CFNetServiceCreateCopy(kCFAllocatorDefault, *(CFNetServiceRef *)signature));
	
	CFWriteStreamRef writeStream;
	CFReadStreamRef readStream;
	
	CFStreamCreatePairWithSocketToNetService(kCFAllocatorDefault, *service, &readStream, &writeStream);
	
	[self _configureWriteStream:(id)writeStream readStream:(id)readStream];
	
	CFRelease(writeStream);
	CFRelease(readStream);
	
	return self;
}

- (AFNetworkLayer *)initWithTransportSignature:(AFNetworkSignature)signature {
	if (CFGetTypeID(*(CFTypeRef *)*(void **)&signature) == CFHostGetTypeID()) {
		return [self _initWithHostSignature:signature._host];
	}
	if (CFGetTypeID(*(CFTypeRef *)*(void **)&signature) == CFNetServiceGetTypeID()) {
		return [self _initWithServiceSignature:signature._service];
	}
	
	[NSException raise:NSInvalidArgumentException format:@"%s, unrecognised signature", __PRETTY_FUNCTION__, nil];
	return nil;
}

- (void)dealloc {
	if (((_connectionFlags & _kConnectionDidOpen) == _kConnectionDidOpen) && ((_connectionFlags & _kConnectionDidClose) != _kConnectionDidClose)) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot dealloc a layer which isn't closed yet.", __PRETTY_FUNCTION__, nil];
		return;
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Note: this is simply shorter to re-address, there is no fancyness, move along
	CFHostRef *peer = &_signature._host.host;
	if (*peer != NULL) {
		// Note: this will also release the netService
		CFRelease(*peer);
		*peer = NULL;
	}
	
	[_writeStream release];
	[_readStream release];
	
	[super dealloc];
}

- (void)finalize {
	if (((_connectionFlags & _kConnectionDidOpen) == _kConnectionDidOpen) && ((_connectionFlags & _kConnectionDidClose) != _kConnectionDidClose)) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot finalize a layer which isn't closed yet.", __PRETTY_FUNCTION__, nil];
		return;
	}
	
	[super finalize];
}

- (id)localAddress {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

- (CFTypeRef)peer {
	// Note: this will also return the netService
	return _signature._host.host;
}

- (id)peerAddress {
	NSParameterAssert(CFGetTypeID([self peer]) == CFHostGetTypeID());
	
	CFHostRef host = (CFHostRef)[self peer];
	return [(id)CFHostGetAddressing(host, NULL) objectAtIndex:0];
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@" {\n"];
	
	[description appendFormat:@"\tPeer: %@\n", [(id)[self peer] description], nil];
	
	[description appendFormat:@"\tOpened: %@, Closed: %@\n", ([self isOpen] ? @"YES" : @"NO"), ([self isClosed] ? @"YES" : @"NO"), nil];
	
	[description appendFormat:@"\tWrite Stream: %@", [self.writeStream description]];
	[description appendFormat:@"\tRead Stream: %@", [self.readStream description]];
	
	if ((_connectionFlags & _kConnectionCloseSoon) == _kConnectionCloseSoon) [description appendString: @"will close pending writes\n"];
	
	[description appendString:@"}"];
	
	return description;
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	[[self writeStream] scheduleInRunLoop:runLoop forMode:mode];
	[[self readStream] scheduleInRunLoop:runLoop forMode:mode];
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	[[self writeStream] unscheduleFromRunLoop:runLoop forMode:mode];
	[[self readStream] unscheduleFromRunLoop:runLoop forMode:mode];
}

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	[[self writeStream] scheduleInQueue:queue];
	[[self readStream] scheduleInQueue:queue];
}

#endif

#pragma mark -
#pragma mark Connection

- (void)open {
	if ([self isOpen]) {
		[self.delegate networkLayerDidOpen:self];
		return;
	}
	
	[[self writeStream] open];
	[[self readStream] open];
}

- (BOOL)isOpen {
	return (_connectionFlags & _kConnectionDidOpen) == _kConnectionDidOpen;
}

- (void)close {
	if ([self isClosed]) {
		[self.delegate networkLayerDidClose:self];
		return;
	}
	
	// Note: you can only prevent a local close, if the streams were closed remotely there's nothing we can do
	if ((_readFlags & _kStreamDidClose) != _kStreamDidClose && (_writeFlags & _kStreamDidClose) != _kStreamDidClose) {
		BOOL pendingWrites = ([self.writeStream countOfEnqueuedPackets] > 0);
		
		if (pendingWrites) {
			BOOL shouldRemainOpen = NO;
			if ([self.delegate respondsToSelector:@selector(networkTransportShouldRemainOpenPendingWrites:)])
				shouldRemainOpen = [self.delegate networkTransportShouldRemainOpenPendingWrites:self];
			
			if (shouldRemainOpen) {
				_connectionFlags = (_connectionFlags | _kConnectionCloseSoon);
				return;
			}
		}
	}
	
	if (self.writeStream != nil) {
		[self.writeStream close];
		_writeFlags = (_writeFlags | _kStreamDidClose);
	}
	
	if (self.readStream != nil) {
		[self.readStream close];
		_readFlags = (_readFlags | _kStreamDidClose);
	}
	
	// Note: set this before the delegation so that the object can be released
	_connectionFlags = (_connectionFlags | _kConnectionDidClose);
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidClose:)]) {
		[self.delegate networkLayerDidClose:self];
	}
}

- (BOOL)isClosed {
	return (_connectionFlags & _kConnectionDidClose) == _kConnectionDidClose;
}

- (BOOL)startTLS:(NSDictionary *)options error:(NSError **)errorRef {
	#warning check that this works :-[
	
	if ((_connectionFlags & _kConnectionWillStartTLS) == _kConnectionWillStartTLS) return YES;
	_connectionFlags = (_connectionFlags | _kConnectionWillStartTLS);
	
	BOOL result = YES;
	if (self.writeStream != nil) result = (result & [self.writeStream setStreamProperty:options forKey:(id)kCFStreamPropertySSLSettings]);
	if (self.readStream != nil) result = (result & [self.readStream setStreamProperty:options forKey:(id)kCFStreamPropertySSLSettings]);
	
	if (!result) {
		if (errorRef != NULL) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  NSLocalizedStringWithDefaultValue(@"AFNetworkTransportTLSError", @"AFNetworkTransport", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Couldn't start TLS, the connection will remain insecure.", nil), NSLocalizedDescriptionKey,
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

- (void)networkStream:(AFNetworkStream *)stream didReceiveEvent:(NSStreamEvent)event {
	NSParameterAssert(stream == [self writeStream] || stream == [self readStream]);
	
	switch (event) {
		case NSStreamEventOpenCompleted:;
			if (stream == [self writeStream]) _writeFlags = (_writeFlags | _kStreamDidOpen);
			else if (stream == [self readStream]) _readFlags = (_readFlags | _kStreamDidOpen);
			
			[self _streamDidOpen];
			return;
		case NSStreamEventHasBytesAvailable:;
		case NSStreamEventHasSpaceAvailable:;
			if ((_connectionFlags & _kConnectionWillStartTLS) != _kConnectionWillStartTLS || (_connectionFlags & _kConnectionDidStartTLS) == _kConnectionDidStartTLS) return;
			
			[self _streamDidStartTLS];
			return;
		case NSStreamEventEndEncountered:;
			if (stream == [self writeStream]) _writeFlags = (_writeFlags | _kStreamDidClose);
			else if (stream == [self readStream]) _readFlags = (_readFlags | _kStreamDidClose);			
			
			[self close];
			return;
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"unknown stream event %lu", event];
	return;
}

- (void)networkStream:(AFNetworkStream *)stream didReceiveError:(NSError *)error {
	if (![self isOpen]) {
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   NSLocalizedStringFromTableInBundle(@"You’re not connected to the Internet", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkTransport offline error description"), NSLocalizedDescriptionKey,
								   NSLocalizedStringFromTableInBundle(@"This computer’s Internet connection appears to be offline.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkTransport offline error recovery suggestion"), NSLocalizedRecoverySuggestionErrorKey,
								   nil];
		error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkTransportErrorUnknown userInfo:errorInfo];
	}
	
	if ([[error domain] isEqualToString:NSPOSIXErrorDomain] && [error code] == ENOTCONN) {
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   NSLocalizedStringFromTableInBundle(@"You’re not connected to the Internet", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkTransport offline error description"), NSLocalizedDescriptionKey,
								   NSLocalizedStringFromTableInBundle(@"This computer’s Internet connection appears to have gone offline.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkTransport offline error recovery suggestion"), NSLocalizedRecoverySuggestionErrorKey,
								   nil];
		error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkTransportErrorUnknown userInfo:errorInfo];
	}
	
	[[self delegate] networkLayer:self didReceiveError:error];
}

#pragma mark Writing

- (void)performWrite:(id)buffer withTimeout:(NSTimeInterval)duration context:(void *)context {
	if ((_connectionFlags & _kConnectionCloseSoon) == _kConnectionCloseSoon) return;
	NSParameterAssert(buffer != nil);
	
	AFNetworkPacketWrite *packet = nil;
	if (![buffer isKindOfClass:[AFNetworkPacket class]]) {
		packet = [[[AFNetworkPacketWrite alloc] initWithData:buffer] autorelease];
	} else {
		packet = buffer;
	}
	
	packet->_duration = duration;
	packet->_context = context;
	
	[self.writeStream enqueuePacket:packet];
}

#pragma mark Reading

- (void)performRead:(id)terminator withTimeout:(NSTimeInterval)duration context:(void *)context {
	if ((_connectionFlags & _kConnectionCloseSoon) == _kConnectionCloseSoon) return;
	NSParameterAssert(terminator != nil);
	
	AFNetworkPacketRead *packet = nil;
	if (![terminator isKindOfClass:[AFNetworkPacket class]]) {
		packet = [[[AFNetworkPacketRead alloc] initWithTerminator:terminator] autorelease];
	} else {
		packet = terminator;
	}
	
	packet->_duration = duration;
	packet->_context = context;
	
	[self.readStream enqueuePacket:packet];
}

@end

#pragma mark -

@implementation AFNetworkTransport (Streams)

- (void)_configureWriteStream:(NSOutputStream *)writeStream readStream:(NSInputStream *)readStream {
	if (writeStream != nil) {
		_writeStream = [[AFNetworkStream alloc] initWithStream:writeStream];
		[_writeStream setDelegate:self];
	}
	
	if (readStream != nil) {
		_readStream = [[AFNetworkStream alloc] initWithStream:readStream];
		[_readStream setDelegate:self];
	}
}

- (void)_streamDidOpen {
	if ((_connectionFlags & _kConnectionDidOpen) == _kConnectionDidOpen) return;
	
	if ([self writeStream] != nil && ((_writeFlags & _kStreamDidOpen) != _kStreamDidOpen)) return;
	if ([self readStream] != nil && ((_readFlags & _kStreamDidOpen) != _kStreamDidOpen)) return;
	_connectionFlags = (_connectionFlags | _kConnectionDidOpen);
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidOpen:)]) {
		[self.delegate networkLayerDidOpen:self];
	}
}

- (BOOL)networkStreamCanDequeuePackets:(AFNetworkStream *)networkStream {
	if ((_connectionFlags & _kConnectionDidOpen) != _kConnectionDidOpen) return NO;
	
	if ((_connectionFlags & _kConnectionWillStartTLS) == _kConnectionWillStartTLS) {
		return ((_connectionFlags & _kConnectionDidStartTLS) == _kConnectionDidStartTLS);
	}
	return YES;
}

- (void)_streamDidStartTLS {
	if ((_connectionFlags & _kConnectionDidStartTLS) == _kConnectionDidStartTLS) return;
	_connectionFlags = (_connectionFlags | _kConnectionDidStartTLS);
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidStartTLS:)]) {
		[self.delegate networkLayerDidStartTLS:self];
	}
}

- (void)networkStream:(AFNetworkStream *)networkStream didTransfer:(AFNetworkPacket *)packet bytesTransferred:(NSInteger)bytesTransferred totalBytesTransferred:(NSInteger)totalBytesTransferred totalBytesExpectedToTransfer:(NSInteger)totalBytesExpectedToTransfer {
	SEL delegateSelector = NULL;
	if (networkStream == [self writeStream]) delegateSelector = @selector(networkTransport:didWritePartialDataOfLength:totalBytesWritten:totalBytesExpectedToWrite:context:);
	else if (networkStream == [self readStream]) delegateSelector = @selector(networkTransport:didReadPartialDataOfLength:totalBytesRead:totalBytesExpectedToRead:context:);
	NSCParameterAssert(delegateSelector != NULL);
	
	if (![[self delegate] respondsToSelector:delegateSelector]) return;
	((void (*)(id, SEL, id, NSUInteger, NSUInteger, NSUInteger, void *))objc_msgSend)([self delegate], delegateSelector, self, bytesTransferred, totalBytesTransferred, totalBytesExpectedToTransfer, [packet context]);
}

- (void)networkStream:(AFNetworkStream *)networkStream didDequeuePacket:(AFNetworkPacket *)networkPacket {
	SEL delegateSelector = NULL;
	if (networkStream == [self writeStream]) delegateSelector = @selector(networkLayer:didWrite:context:);
	else if (networkStream == [self readStream]) delegateSelector = @selector(networkLayer:didRead:context:);
	NSCParameterAssert(delegateSelector != NULL);
	
	((void (*)(id, SEL, id, id, void *))objc_msgSend)([self delegate], delegateSelector, self, [networkPacket buffer], [networkPacket context]);
	
	
	if (networkStream == [self writeStream]) {
		if ((_connectionFlags & _kConnectionCloseSoon) != _kConnectionCloseSoon) return;
		if ([self.writeStream countOfEnqueuedPackets] != 0) return;
		
		[self close];
		return;
	}
}

@end
