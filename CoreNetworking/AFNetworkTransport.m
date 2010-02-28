//
//  AFNetworkTransport.m
//	Amber
//
//	Originally based on AsyncSocket http://code.google.com/p/cocoaasyncsocket/
//	Although the class is now much departed from the original codebase.
//
//  Created by Keith Duncan
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFNetworkTransport.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

#import <arpa/inet.h>
#import <sys/socket.h>
#import "AmberFoundation/AmberFoundation.h"
#import <netdb.h>
#import <objc/runtime.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "AFNetworkSocket.h"
#import "AFNetworkConstants.h"
#import "AFNetworkFunctions.h"

#import "AFPacketQueue.h"
#import "AFStreamPacketQueue.h"
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

NSSTRING_CONTEXT(AFNetworkTransportPacketQueueObservationContext);

@interface AFNetworkTransport ()
@property (assign) NSUInteger connectionFlags;

@property (readonly) AFStreamPacketQueue *readQueue, *writeQueue;

@property (readonly) CFWriteStreamRef writeStream;
@property (readonly) CFReadStreamRef readStream;
@end

@interface AFNetworkTransport (Streams)
- (BOOL)_configureWriteStream:(CFWriteStreamRef)writeStream readStream:(CFReadStreamRef)readStream;
- (void)_streamDidOpen;
- (void)_streamDidStartTLS;
@end

@interface AFNetworkTransport (PacketQueue) <AFStreamPacketQueueDelegate>
- (void)_tryDequeuePackets;
- (void)_emptyQueues;
@end

static void AFNetworkTransportWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, AFNetworkTransport *self);
static void AFNetworkTransportReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, AFNetworkTransport *self);

#pragma mark -

@implementation AFNetworkTransport

@dynamic delegate;
@synthesize connectionFlags=_connectionFlags;
@synthesize writeQueue=_writeQueue, readQueue=_readQueue;

+ (Class)lowerLayer {
	return [AFNetworkSocket class];
}

- (id)initWithLowerLayer:(id <AFTransportLayer>)layer {
	self = [super initWithLowerLayer:layer];
	if (self == nil) return nil;
	
	NSParameterAssert([layer isKindOfClass:[AFNetworkSocket class]]);
	
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
	
	[self _configureWriteStream:writeStream readStream:readStream];
	
	// Note: ensure this is done in the same method as setting the socket options to essentially balance a retain/release on the native socket
	if (shouldCloseUnderlyingSocket) {
		CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
		CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	}
	
	CFRelease(writeStream);
	CFRelease(readStream);
	
	return self;
}

- (id <AFConnectionLayer>)_initWithHostSignature:(AFNetworkTransportHostSignature *)signature {
	self = [self init];
	if (self == nil) return nil;
	
	memcpy(&_signature._host, signature, sizeof(AFNetworkTransportHostSignature));
	
	CFHostRef *host = &_signature._host.host;
	*host = (CFHostRef)NSMakeCollectable(CFRetain(signature->host));
	
	CFWriteStreamRef writeStream;
	CFReadStreamRef readStream;
	
	CFStreamCreatePairWithSocketToCFHost(kCFAllocatorDefault, *host, _signature._host.transport.port, &readStream, &writeStream);
	
	[self _configureWriteStream:writeStream readStream:readStream];
	
	CFRelease(writeStream);
	CFRelease(readStream);
	
	return self;
}

- (id <AFConnectionLayer>)_initWithServiceSignature:(AFNetworkTransportServiceSignature *)signature {
	self = [self init];
	if (self == nil) return nil;
	
	CFNetServiceRef *service = &_signature._service.service;
	*service = (CFNetServiceRef)CFMakeCollectable(CFNetServiceCreateCopy(kCFAllocatorDefault, *(CFNetServiceRef *)signature));
	
	CFWriteStreamRef writeStream;
	CFReadStreamRef readStream;
	
	CFStreamCreatePairWithSocketToNetService(kCFAllocatorDefault, *service, &readStream, &writeStream);
	
	[self _configureWriteStream:writeStream readStream:readStream];
	
	CFRelease(writeStream);
	CFRelease(readStream);
	
	return self;
}

- (AFNetworkLayer *)initWithTransportSignature:(AFNetworkTransportSignature)signature {
	if (CFGetTypeID(*(CFTypeRef *)&signature) == CFHostGetTypeID()) {
		return [self _initWithHostSignature:signature._host];
	}
	if (CFGetTypeID(*(CFTypeRef *)&signature) == CFNetServiceGetTypeID()) {
		return [self _initWithServiceSignature:signature._service];
	}
	
	[NSException raise:NSInvalidArgumentException format:@"%s, unrecognised signature", __PRETTY_FUNCTION__, nil];
	return nil;
}

- (void)finalize {
	if (![self isClosed]) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot finalize a layer which isn't closed yet.", __PRETTY_FUNCTION__, nil];
		return;
	}
	
	if (_writeQueueSource != NULL) {
		dispatch_release(_writeQueueSource);
	}
	if (_readQueueSource != NULL) {
		dispatch_release(_readQueueSource);
	}
	
	[super finalize];
}

- (void)dealloc {
	if (![self isClosed]) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot dealloc a layer which isn't closed yet.", __PRETTY_FUNCTION__, nil];
		return;
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// Note: this will also release the netService if present
	CFHostRef *peer = &_signature._host.host; // Note: this is simply shorter to re-address, there is no fancyness, move along
	if (*peer != NULL) {
		CFRelease(*peer);
		*peer = NULL;
	}
	
	[_writeQueue release];
	[_readQueue release];
	
	if (_writeQueueSource != NULL) {
		dispatch_release(_writeQueueSource);
	}
	if (_readQueueSource != NULL) {
		dispatch_release(_readQueueSource);
	}
	
	[super dealloc];
}

- (CFWriteStreamRef)writeStream {
	return (CFWriteStreamRef)self.writeQueue.stream;
}

- (CFReadStreamRef)readStream {
	return (CFReadStreamRef)self.readQueue.stream;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &AFNetworkTransportPacketQueueObservationContext) {
		id oldPacket = [change objectForKey:NSKeyValueChangeOldKey];
		
		if (oldPacket != nil && ![oldPacket isEqual:[NSNull null]]) {
			[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketTimeoutNotificationName object:oldPacket];
			[oldPacket stopTimeout];
		}
		
		id newPacket = [change objectForKey:NSKeyValueChangeNewKey];
		
		if (newPacket == nil || [newPacket isEqual:[NSNull null]]) {
			if (object == self.writeQueue) {
				BOOL shouldClose = YES;
				shouldClose &= ((self.connectionFlags & _kConnectionCloseSoon) == _kConnectionCloseSoon);
				shouldClose &= ([self.writeQueue count] == 0);
				if (shouldClose) [self close];
			}
			
			return;
		}
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_packetTimeoutNotification:) name:AFPacketTimeoutNotificationName object:newPacket];
		[newPacket startTimeout];
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
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
	
	[description appendFormat:@"\tOpen: %@, Closed: %@\n", ([self isOpen] ? @"YES" : @"NO"), ([self isClosed] ? @"YES" : @"NO"), nil];
	
	[description appendFormat:@"\t%d pending reads, %d pending writes\n", [self.readQueue count], [self.writeQueue count], nil];
	
	static const char *StreamStatusStrings[] = { "not open", "opening", "open", "reading", "writing", "at end", "closed", "has error" };
	
	[description appendFormat:@"\tRead Stream: %p %s, ", self.readStream, (self.readStream != NULL ? StreamStatusStrings[CFReadStreamGetStatus((CFReadStreamRef)self.readStream)] : ""), nil];
	[description appendFormat:@"Current Read: %@", [self.readQueue currentPacket], nil];
	[description appendString:@"\n"];
	
	[description appendFormat:@"\tWrite Stream: %p %s, ", self.writeStream, (self.writeStream != NULL ? StreamStatusStrings[CFWriteStreamGetStatus((CFWriteStreamRef)self.writeStream)] : ""), nil];	
	[description appendFormat:@"Current Write: %@", [self.writeQueue currentPacket], nil];
	[description appendString:@"\n"];
	
	if ((self.connectionFlags & _kConnectionCloseSoon) == _kConnectionCloseSoon) [description appendString: @"will close pending writes\n"];
	
	[description appendString:@"}"];
	
	return description;
}

- (void)scheduleInRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode {
	CFWriteStreamScheduleWithRunLoop(self.writeStream, [loop getCFRunLoop], (CFStringRef)mode);
	CFReadStreamScheduleWithRunLoop(self.readStream, [loop getCFRunLoop], (CFStringRef)mode);
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode {
	CFWriteStreamUnscheduleFromRunLoop(self.writeStream, [loop getCFRunLoop], (CFStringRef)mode);
	CFReadStreamUnscheduleFromRunLoop(self.readStream, [loop getCFRunLoop], (CFStringRef)mode);
}

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	typedef id (*CopyStreamProperty)(CFTypeRef, CFStringRef);
	typedef CFSocketNativeHandle (^GetNativeSteamHandle)(CopyStreamProperty copyProperty, CFTypeRef stream);
	GetNativeSteamHandle getNativeHandle = ^ CFSocketNativeHandle (CopyStreamProperty copyProperty, CFTypeRef stream) {
		CFSocketNativeHandle handle = 0;
		NSData *handleData = [NSMakeCollectable(copyProperty(stream, kCFStreamPropertySocketNativeHandle)) autorelease];
		NSParameterAssert(handleData != nil && [handleData length] > 0 && sizeof(CFSocketNativeHandle) <= [handleData length]);
		[handleData getBytes:&handle length:[handleData length]];
		
		return handle;
	};
	
	if (_writeQueueSource != NULL) {
		dispatch_source_cancel(_writeQueueSource);
		dispatch_release(_writeQueueSource);
		_writeQueueSource = NULL;
	}
	
	if (_readQueueSource != NULL) {
		dispatch_source_cancel(_readQueueSource);
		dispatch_release(_readQueueSource);
		_readQueueSource = NULL;
	}
	
	if (queue == NULL) return;
	
	if (_writeQueueSource == NULL) {
		dispatch_source_t writeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, getNativeHandle((CopyStreamProperty)CFWriteStreamCopyProperty, [self writeStream]), 0, queue);
		dispatch_source_set_event_handler(writeSource, ^ {
			AFNetworkTransportWriteStreamCallback([self writeStream], kCFStreamEventCanAcceptBytes, self);
		});
		dispatch_resume(writeSource);
		_writeQueueSource = writeSource;
	}
	
	if (_readQueueSource == NULL) {
		dispatch_source_t readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, getNativeHandle((CopyStreamProperty)CFReadStreamCopyProperty, [self readStream]), 0, queue);
		dispatch_source_set_event_handler(readSource, ^ {
			AFNetworkTransportReadStreamCallback([self readStream], kCFStreamEventHasBytesAvailable, self);
		});
		dispatch_resume(readSource);
		_readQueueSource = readSource;
	}
}

#endif

#pragma mark -
#pragma mark Connection

static BOOL _AFSocketConnectionReachabilityResult(CFDataRef data) {
    SCNetworkConnectionFlags *flags = (SCNetworkConnectionFlags *)CFDataGetBytePtr(data);
    NSCAssert(flags != NULL, @"reachability flags must not be NULL.");
	
	BOOL reachable = (*flags & kSCNetworkFlagsReachable) 
						&& !(*flags & kSCNetworkFlagsConnectionRequired)
						&& !(*flags & kSCNetworkFlagsConnectionAutomatic)
						&& !(*flags & kSCNetworkFlagsInterventionRequired);
	
	return reachable;
}

- (void)open {
	if ([self isOpen]) {
		[self.delegate layerDidOpen:self];
		return;
	}
	
	if (CFGetTypeID([self peer]) == CFHostGetTypeID()) {
		CFHostRef host = (CFHostRef)self.peer;
		
		CFStreamError error = {0};
		
		Boolean result = false;
		result = CFHostStartInfoResolution(host, kCFHostReachability, &error);
		
		CFDataRef reachability = CFHostGetReachability(host, &result);
		BOOL reachable = _AFSocketConnectionReachabilityResult(reachability);
		
		if (!reachable || error.domain != 0) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  (id)reachability, @"reachbilityFlagsData",
									  NSLocalizedStringWithDefaultValue(@"AFSocketConnectionReachabilityError", @"AFSocketConnection", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Cannot reach the destination host with your current network configuration.", nil), NSLocalizedDescriptionKey,
									  (error.domain != 0 ? AFErrorFromCFStreamError(error) : nil), NSUnderlyingErrorKey, // Note: this key-value pair must come last, it contains a conditional nil sentinel
									  nil];
			
			NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkTransportReachabilityError userInfo:userInfo];
			[self.delegate layer:self didNotOpen:error];
			
			return;
		}
	}
	
	Boolean result = true;
	result &= CFWriteStreamOpen(self.writeStream);
	result &= CFReadStreamOpen(self.readStream);
	
	if (!result) {
		[self close];
		[self.delegate layer:self didNotOpen:nil];
	}
}

- (BOOL)isOpen {
	return (self.connectionFlags & _kConnectionDidOpen) == _kConnectionDidOpen;
}

- (void)waitUntilOpen {
	CFStreamStatus writeStatus = kCFStreamStatusError;
	do {
		writeStatus = CFWriteStreamGetStatus([self writeStream]);
	} while (writeStatus != kCFStreamStatusOpen && writeStatus != kCFStreamStatusError);
	
	CFStreamStatus readStatus = kCFStreamStatusError;
	do {
		readStatus = CFReadStreamGetStatus([self readStream]);
	} while (readStatus != kCFStreamStatusOpen && readStatus != kCFStreamStatusError);
}

- (void)close {
	if ([self isClosed]) {
		[self.delegate layerDidClose:self];
		return;
	}
	
	// Note: you can only prevent a local close, if the streams were closed remotely there's nothing we can do
	if ((self.readQueue.flags & _kStreamDidClose) != _kStreamDidClose && (self.writeQueue.flags & _kStreamDidClose) != _kStreamDidClose) {
		BOOL pendingWrites = ([self.writeQueue currentPacket] != nil || [self.writeQueue count] > 0);
		
		if (pendingWrites) {
			BOOL shouldRemainOpen = NO;
			if ([self.delegate respondsToSelector:@selector(socket:shouldRemainOpenPendingWrites:)])
				shouldRemainOpen = [self.delegate socket:self shouldRemainOpenPendingWrites:([self.writeQueue count] + 1)];
		
			if (shouldRemainOpen) {
				self.connectionFlags = (self.connectionFlags | _kConnectionCloseSoon);
				return;
			}
		}
	}
	
	[self.writeQueue removeObserver:self forKeyPath:@"currentPacket"];
	[self.readQueue removeObserver:self forKeyPath:@"currentPacket"];
	[self _emptyQueues];
	
	NSError *streamError = nil;
	
	if (self.readStream != NULL) {
		if (streamError == nil)
			streamError = [NSMakeCollectable(CFReadStreamCopyError(self.readStream)) autorelease];
		
		CFReadStreamSetClient(self.readStream, kCFStreamEventNone, NULL, NULL);
		CFReadStreamClose(self.readStream);
		
		self.readQueue.flags = (self.readQueue.flags | _kStreamDidClose);
	}
	
	if (self.writeStream != NULL) {
		if (streamError == nil) // Note: this guards against overwriting a non-nil error with a nil pointer
			streamError = [NSMakeCollectable(CFWriteStreamCopyError(self.writeStream)) autorelease];
		
		CFWriteStreamSetClient(self.writeStream, kCFStreamEventNone, NULL, NULL);
		CFWriteStreamClose(self.writeStream);
		
		self.writeQueue.flags = (self.writeQueue.flags | _kStreamDidClose);
	}
	
	// Note: set this before the delegation so that the object can be released
	self.connectionFlags = _kConnectionDidClose;
	
	if ([self.delegate respondsToSelector:@selector(layer:didDisconnectWithError:)])
		[self.delegate layer:self didDisconnectWithError:streamError];
	
	if ([self.delegate respondsToSelector:@selector(layerDidClose:)])
		[self.delegate layerDidClose:self];
}

- (BOOL)isClosed {
	return (self.connectionFlags & _kConnectionDidClose) == _kConnectionDidClose;
}

- (BOOL)startTLS:(NSDictionary *)options error:(NSError **)errorRef {
	if ((self.connectionFlags & _kConnectionWillStartTLS) == _kConnectionWillStartTLS) return YES;
	self.connectionFlags = (self.connectionFlags | _kConnectionWillStartTLS);
	
	Boolean result = true;
	result = (result & CFWriteStreamSetProperty(self.writeStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options));
	result = (result & CFReadStreamSetProperty(self.readStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options));
	
	if (!result) {
		if (errorRef != NULL) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  NSLocalizedStringWithDefaultValue(@"AFNetworkTransportTLSError", @"AFNetworkTransport", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Couldn't start TLS, the connection will remain insecure.", nil), NSLocalizedDescriptionKey,
									  nil];
			*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkTransportTLSError userInfo:userInfo];
		}
		
		return NO;
	}
	
	return YES;
}

#pragma mark Writing

- (void)performWrite:(id)buffer withTimeout:(NSTimeInterval)duration context:(void *)context {
	if ((self.connectionFlags & _kConnectionCloseSoon) == _kConnectionCloseSoon) return;
	NSParameterAssert(buffer != nil);
	
	AFPacketWrite *packet = nil;
	if ([buffer isKindOfClass:[AFPacket class]]) {
		packet = buffer;
		
		packet->_duration = duration;
		packet->_context = context;
	} else {
		packet = [[[AFPacketWrite alloc] initWithContext:context timeout:duration data:buffer] autorelease];
	}
	
	if ([self.delegate respondsToSelector:@selector(socket:willEnqueueWritePacket:)])
		[self.delegate socket:self willEnqueueWritePacket:packet];
	
	[self.writeQueue enqueuePacket:packet];
	[self.writeQueue tryDequeuePackets];
}

static void AFNetworkTransportWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, AFNetworkTransport *self) {
	NSCParameterAssert(stream == self.writeStream);
	
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			self.writeQueue.flags = (self.writeQueue.flags | _kStreamDidOpen);
			
			[self _streamDidOpen];
			break;
		}
		case kCFStreamEventCanAcceptBytes:
		{
			if ((self.connectionFlags & _kConnectionWillStartTLS) == _kConnectionWillStartTLS) {
				[self _streamDidStartTLS];
			} else [self.writeQueue tryDequeuePackets];
			
			break;
		}
		case kCFStreamEventErrorOccurred:
		{
			NSError *error = AFErrorFromCFStreamError(CFReadStreamGetError(self.readStream));			
			[self.delegate layer:self didReceiveError:error];
			
			break;
		}
		case kCFStreamEventEndEncountered:
		{			
			[self close];
			break;
		}
		default:
		{
			NSLog(@"%s, %p, received unexpected CFWriteStream callback, CFStreamEventType %d.", __PRETTY_FUNCTION__, self, type, nil);
			break;
		}
	}
	
	[pool drain];
}

#pragma mark Reading

- (void)performRead:(id)terminator withTimeout:(NSTimeInterval)duration context:(void *)context {
	if ((self.connectionFlags & _kConnectionCloseSoon) == _kConnectionCloseSoon) return;
	NSParameterAssert(terminator != nil);
	
	AFPacketRead *packet = nil;
	if ([terminator isKindOfClass:[AFPacket class]]) {
		packet = terminator;
		
		packet->_duration = duration;
		packet->_context = context;
	} else {
		packet = [[[AFPacketRead alloc] initWithContext:context timeout:duration terminator:terminator] autorelease];
	}
	
	if ([self.delegate respondsToSelector:@selector(socket:willEnqueueReadPacket:)])
		[self.delegate socket:self willEnqueueReadPacket:packet];
	
	[self.readQueue enqueuePacket:packet];
	[self.readQueue tryDequeuePackets];
}

static void AFNetworkTransportReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, AFNetworkTransport *self) {
	NSCParameterAssert(stream == self.readStream);
	
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			self.readQueue.flags = (self.readQueue.flags | _kStreamDidOpen);
			
			[self _streamDidOpen];
			break;
		}
		case kCFStreamEventHasBytesAvailable:
		{	
			if ((self.connectionFlags & _kConnectionWillStartTLS) == _kConnectionWillStartTLS) {
				[self _streamDidStartTLS];
			} else [self.readQueue tryDequeuePackets];
			
			break;
		}
		case kCFStreamEventErrorOccurred:
		{
			NSError *error = AFErrorFromCFStreamError(CFReadStreamGetError(self.readStream));
			[self.delegate layer:self didReceiveError:error];
			
			break;
		}
		case kCFStreamEventEndEncountered:
		{
			[self close];
			break;
		}
		default:
		{
			NSLog(@"%s, %p received unexpected CFReadStream callback, CFStreamEventType %d.", __PRETTY_FUNCTION__, self, type, nil);
			break;
		}
	}
	
	[pool drain];
}

@end

#pragma mark -

@implementation AFNetworkTransport (Streams)

- (BOOL)_configureWriteStream:(CFWriteStreamRef)writeStream readStream:(CFReadStreamRef)readStream {
	Boolean result = true;
	
	CFStreamClientContext context = {0};
	context.info = self;
	
	CFStreamEventType sharedTypes = (kCFStreamEventOpenCompleted | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered);
	
	if (writeStream != NULL) {
		_writeQueue = [[AFStreamPacketQueue alloc] initWithStream:(id)writeStream delegate:self];
		[_writeQueue addObserver:self forKeyPath:@"currentPacket" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:&AFNetworkTransportPacketQueueObservationContext];
		
		result &= CFWriteStreamSetClient(self.writeStream, (sharedTypes | kCFStreamEventCanAcceptBytes), (CFWriteStreamClientCallBack)AFNetworkTransportWriteStreamCallback, &context);
	}
	
	if (readStream != NULL) {
		_readQueue = [[AFStreamPacketQueue alloc] initWithStream:(id)readStream delegate:self];
		[_readQueue addObserver:self forKeyPath:@"currentPacket" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:&AFNetworkTransportPacketQueueObservationContext];
		
		result &= CFReadStreamSetClient(self.readStream, (sharedTypes | kCFStreamEventHasBytesAvailable), (CFReadStreamClientCallBack)AFNetworkTransportReadStreamCallback, &context);
	}
	
	return result;
}

- (void)_streamDidOpen {
	if ((self.connectionFlags & _kConnectionDidOpen) == _kConnectionDidOpen) return;
	
	if ((self.readQueue.flags & _kStreamDidOpen) != _kStreamDidOpen || (self.writeQueue.flags & _kStreamDidOpen) != _kStreamDidOpen) return;
	self.connectionFlags = (self.connectionFlags | _kConnectionDidOpen);
	
	if ([self.delegate respondsToSelector:@selector(layerDidOpen:)])
		[self.delegate layerDidOpen:self];
	
	if ([self.delegate respondsToSelector:@selector(layer:didConnectToPeer:)])
		[self.delegate layer:self didConnectToPeer:(id)[self peer]];
}

- (void)_streamDidStartTLS {
	if ((self.connectionFlags & _kConnectionDidStartTLS) == _kConnectionDidStartTLS) return;
	self.connectionFlags = (self.connectionFlags | _kConnectionDidStartTLS);
	
	if ([self.delegate respondsToSelector:@selector(layerDidStartTLS:)])
		[self.delegate layerDidStartTLS:self];
}

@end

#pragma mark -

@implementation AFNetworkTransport (PacketQueue)

- (void)_tryDequeuePackets {
	[self.writeQueue tryDequeuePackets];
	[self.readQueue tryDequeuePackets];
}

- (void)_emptyQueues {
	[self.writeQueue emptyQueue];
	[self.readQueue emptyQueue];
}

- (void)_packetTimeoutNotification:(NSNotification *)notification {
	NSError *error = nil;
	
	if ([[notification object] isEqual:[self.readQueue currentPacket]]) {
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketConnectionReadTimeoutError", @"AFSocketConnection", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Read operation timeout.", nil), NSLocalizedDescriptionKey,
							  nil];
		error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkTransportReadTimeoutError userInfo:errorInfo];
	} else if ([[notification object] isEqual:[self.writeQueue currentPacket]]) {
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketConnectionWriteTimeoutError", @"AFSocketConnection", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Write operation timeout.", nil), NSLocalizedDescriptionKey,
							  nil];
		error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkTransportWriteTimeoutError userInfo:errorInfo];
	}
	
	[self.delegate layer:self didReceiveError:error];
}

- (BOOL)streamQueueCanDequeuePackets:(AFStreamPacketQueue *)queue {
	if ((self.connectionFlags & _kConnectionWillStartTLS) == _kConnectionWillStartTLS) {
		return ((self.connectionFlags & _kConnectionDidStartTLS) != _kConnectionDidStartTLS);
	}
	return YES;
}

- (BOOL)streamQueue:(AFStreamPacketQueue *)queue shouldTryDequeuePacket:(AFPacket *)packet {
	if (queue == self.readQueue) {
		NSError *error = nil;
		BOOL packetComplete = [(id)packet performRead:(CFReadStreamRef)queue.stream error:&error];
		
		if (error != nil) {
			[self.delegate layer:self didReceiveError:error];
			return YES;
		}
		
		if ([self.delegate respondsToSelector:@selector(socket:didReadPartialDataOfLength:total:context:)]) {
			NSUInteger bytesRead = 0, bytesTotal = 0;
			[packet currentProgressWithBytesDone:&bytesRead bytesTotal:&bytesTotal];
			
			[self.delegate socket:self didReadPartialDataOfLength:bytesRead total:bytesTotal context:packet.context];
		}
		
		if (packetComplete) {
			[self.delegate layer:self didRead:packet.buffer context:packet.context];
			return YES;
		}
	} else if (queue == self.writeQueue) {
		NSError *error = nil;
		BOOL packetComplete = [(id)packet performWrite:(CFWriteStreamRef)queue.stream error:&error];
		
		if (error != nil) {
			[self.delegate layer:self didReceiveError:error];
			return YES;
		}
		
		if ([self.delegate respondsToSelector:@selector(socket:didWritePartialDataOfLength:total:context:)]) {
			NSUInteger bytesWritten = 0, totalBytes = 0;
			[packet currentProgressWithBytesDone:&bytesWritten bytesTotal:&totalBytes];
			
			[self.delegate socket:self didWritePartialDataOfLength:bytesWritten total:totalBytes context:packet.context];
		}
		
		if (packetComplete) {
			[self.delegate layer:self didWrite:packet.buffer context:packet.context];
			return YES;
		}
	}
	
	return NO;
}

@end
