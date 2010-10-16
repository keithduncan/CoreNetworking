//
//  AFNetworkTransport.m
//	Amber
//
//	Originally based on AsyncSocket http://code.google.com/p/cocoaasyncsocket/
//	Although the class is now much departed from the original codebase.
//
//  Created by Keith Duncan
//  Copyright 2008 software. All rights reserved.
//

#import "AFNetworkTransport.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif
#import <objc/runtime.h>
#import <objc/message.h>
#import <arpa/inet.h>
#import <sys/socket.h>
#import <netdb.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import "AmberFoundation/AmberFoundation.h"

#import "AFNetworkSocket.h"
#import "AFNetworkConstants.h"
#import "AFNetworkFunctions.h"
#import "AFNetworkStream.h"
#import "AFPacketQueue.h"
#import "AFPacketRead.h"
#import "AFPacketWrite.h"

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
@property (readonly) AFNetworkWriteStream *writeStream;
@property (readonly) AFNetworkReadStream *readStream;
static void _AFNetworkTransportStreamDidPartialPacket(AFNetworkTransport *self, SEL _cmd, AFNetworkStream *stream, AFPacket *packet, NSUInteger currentPartialBytes, NSUInteger totalBytes);
static void _AFNetworkTransportStreamDidCompletePacket(AFNetworkTransport *self, SEL _cmd, AFNetworkStream *stream, AFPacket *packet);
@end

// Note: the selectors aren't all actually implemented, some are added dynamically
@interface AFNetworkTransport (Delegate) <AFNetworkWriteStreamDelegate, AFNetworkReadStreamDelegate>
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

+ (void)initialize {
	if (self != [AFNetworkTransport class]) return;
	
	class_addMethod(self, @selector(networkStream:didWrite:partialDataOfLength:totalLength:), (IMP)_AFNetworkTransportStreamDidPartialPacket, "v@:@II");
	class_addMethod(self, @selector(networkStream:didRead:partialDataOfLength:totalLength:), (IMP)_AFNetworkTransportStreamDidPartialPacket, "v@:@II");
	
	class_addMethod(self, @selector(networkStream:didWrite:), (IMP)_AFNetworkTransportStreamDidCompletePacket, "v@:@@");
	class_addMethod(self, @selector(networkStream:didRead:), (IMP)_AFNetworkTransportStreamDidCompletePacket, "v@:@@");
}

+ (Class)lowerLayer {
	return [AFNetworkSocket class];
}

- (id)initWithLowerLayer:(id <AFTransportLayer>)layer {
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

- (id <AFConnectionLayer>)_initWithHostSignature:(AFNetworkHostSignature *)signature {
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

- (id <AFConnectionLayer>)_initWithServiceSignature:(AFNetworkServiceSignature *)signature {
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
		[self.delegate layerDidOpen:self];
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
		[self.delegate layerDidClose:self];
		return;
	}
	
	// Note: you can only prevent a local close, if the streams were closed remotely there's nothing we can do
	if ((_readFlags & _kStreamDidClose) != _kStreamDidClose && (_writeFlags & _kStreamDidClose) != _kStreamDidClose) {
		BOOL pendingWrites = ([self.writeStream countOfEnqueuedWrites] > 0);
		
		if (pendingWrites) {
			BOOL shouldRemainOpen = NO;
			if ([self.delegate respondsToSelector:@selector(transportShouldRemainOpenPendingWrites:)])
				shouldRemainOpen = [self.delegate transportShouldRemainOpenPendingWrites:self];
			
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
	
	if ([self.delegate respondsToSelector:@selector(layerDidClose:)])
		[self.delegate layerDidClose:self];
}

- (BOOL)isClosed {
	return (_connectionFlags & _kConnectionDidClose) == _kConnectionDidClose;
}

- (BOOL)startTLS:(NSDictionary *)options error:(NSError **)errorRef {
	if ((_connectionFlags & _kConnectionWillStartTLS) == _kConnectionWillStartTLS) return YES;
	_connectionFlags = (_connectionFlags | _kConnectionWillStartTLS);
	
	BOOL result = YES;
	if (self.writeStream != nil) result = (result & [self.writeStream setStreamProperty:options forKey:(id)kCFStreamPropertySSLSettings]);
	if (self.readStream != nil) result = (result & [self.readStream setStreamProperty:options forKey:(id)kCFStreamPropertySSLSettings]);
#warning check that this works :-[
	
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
		case NSStreamEventOpenCompleted:
		{
			if (stream == [self writeStream]) _writeFlags = (_writeFlags | _kStreamDidOpen);
			else if (stream == [self readStream]) _readFlags = (_readFlags | _kStreamDidOpen);
			
			[self _streamDidOpen];
			return;
		}
		case NSStreamEventEndEncountered:
		{
			if (stream == [self writeStream]) _writeFlags = (_writeFlags | _kStreamDidClose);
			else if (stream == [self readStream]) _readFlags = (_readFlags | _kStreamDidClose);			
			
			[self close];
			return;
		}
	}
	
	if ([[self delegate] respondsToSelector:@selector(networkStream:didReceiveEvent:)])
		[(id)[self delegate] networkStream:stream didReceiveEvent:event];
}

- (void)networkStream:(AFNetworkStream *)stream didReceiveError:(NSError *)error {
	[[self delegate] layer:self didReceiveError:error];
}

#pragma mark Writing

- (void)performWrite:(id)buffer withTimeout:(NSTimeInterval)duration context:(void *)context {
	if ((_connectionFlags & _kConnectionCloseSoon) == _kConnectionCloseSoon) return;
	NSParameterAssert(buffer != nil);
	
	AFPacketWrite *packet = nil;
	if ([buffer isKindOfClass:[AFPacket class]]) {
		packet = buffer;
		
		packet->_duration = duration;
		packet->_context = context;
	} else {
		packet = [[[AFPacketWrite alloc] initWithContext:context timeout:duration data:buffer] autorelease];
	}
	
	[self.writeStream enqueueWrite:packet];
}

#pragma mark Reading

- (void)performRead:(id)terminator withTimeout:(NSTimeInterval)duration context:(void *)context {
	if ((_connectionFlags & _kConnectionCloseSoon) == _kConnectionCloseSoon) return;
	NSParameterAssert(terminator != nil);
	
	AFPacketRead *packet = nil;
	if ([terminator isKindOfClass:[AFPacket class]]) {
		packet = terminator;
		
		packet->_duration = duration;
		packet->_context = context;
	} else {
		packet = [[[AFPacketRead alloc] initWithContext:context timeout:duration terminator:terminator] autorelease];
	}
	
	[self.readStream enqueueRead:packet];
}

#pragma mark -
#pragma mark Writing & Reading

static void _AFNetworkTransportStreamDidPartialPacket(AFNetworkTransport *self, SEL _cmd, AFNetworkStream *stream, AFPacket *packet, NSUInteger partialLength, NSUInteger totalLength) {
	SEL delegateSelector = NULL;
	if (stream == self->_writeStream) delegateSelector = @selector(transport:didWritePartialDataOfLength:totalLength:context:);
	else if (stream == self->_readStream) delegateSelector = @selector(transport:didReadPartialDataOfLength:totalLength:context:);
	NSCParameterAssert(delegateSelector != NULL);
	
	if (![[self delegate] respondsToSelector:delegateSelector]) return;
	((void (*)(id, SEL, NSUInteger, NSUInteger, void *))objc_msgSend)([self delegate], delegateSelector, partialLength, totalLength, [packet context]);
}

static void _AFNetworkTransportStreamDidCompletePacket(AFNetworkTransport *self, SEL _cmd, AFNetworkStream *stream, AFPacket *packet) {
	SEL delegateSelector = NULL;
	if (stream == self->_writeStream) delegateSelector = @selector(layer:didWrite:context:);
	else if (stream == self->_readStream) delegateSelector = @selector(layer:didRead:context:);
	NSCParameterAssert(delegateSelector != NULL);
	
	((void (*)(id, SEL, id, id, void *))objc_msgSend)([self delegate], delegateSelector, self, [packet buffer], [packet context]);
}

@end

#pragma mark -

@implementation AFNetworkTransport (Streams)

- (void)_configureWriteStream:(NSOutputStream *)writeStream readStream:(NSInputStream *)readStream {
	if (writeStream != nil) {
		_writeStream = [[AFNetworkWriteStream alloc] initWithStream:writeStream];
		[_writeStream setDelegate:self];
	}
	
	if (readStream != nil) {
		_readStream = [[AFNetworkReadStream alloc] initWithStream:readStream];
		[_readStream setDelegate:self];
	}
}

- (void)_streamDidOpen {
	if ((_connectionFlags & _kConnectionDidOpen) == _kConnectionDidOpen) return;
	
	if ([self writeStream] != nil && ((_writeFlags & _kStreamDidOpen) != _kStreamDidOpen)) return;
	if ([self readStream] != nil && ((_readFlags & _kStreamDidOpen) != _kStreamDidOpen)) return;
	_connectionFlags = (_connectionFlags | _kConnectionDidOpen);
	
	if ([self.delegate respondsToSelector:@selector(layerDidOpen:)])
		[self.delegate layerDidOpen:self];
}

- (BOOL)networkStreamCanDequeuePackets:(AFNetworkStream *)networkStream {
	if ((_connectionFlags & _kConnectionWillStartTLS) == _kConnectionWillStartTLS) {
		return ((_connectionFlags & _kConnectionDidStartTLS) == _kConnectionDidStartTLS);
	}
	return YES;
}

- (void)_streamDidStartTLS {
	if ((_connectionFlags & _kConnectionDidStartTLS) == _kConnectionDidStartTLS) return;
	_connectionFlags = (_connectionFlags | _kConnectionDidStartTLS);
	
	if ([self.delegate respondsToSelector:@selector(layerDidStartTLS:)])
		[self.delegate layerDidStartTLS:self];
}

- (void)networkStreamDidDequeuePacket:(AFNetworkStream *)networkStream {
	if (networkStream != [self writeStream]) return;
	if ((_connectionFlags & _kConnectionCloseSoon) != _kConnectionCloseSoon) return;
	if ([self.writeStream countOfEnqueuedWrites] != 0) return;
	
	[self close];
}

@end
