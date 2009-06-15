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
#import "AmberFoundation/AmberFoundation.h"
#import <netdb.h>
#import <objc/runtime.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <sys/socket.h>

#import "AFNetworkSocket.h"
#import "AFNetworkConstants.h"
#import "AFNetworkFunctions.h"

#import "AFPacketQueue.h"
#import "AFPacketRead.h"
#import "AFPacketWrite.h"

enum {
	_kEnablePreBuffering		= 1UL << 0,   // pre-buffering is enabled
	_kDidCallConnectDelegate	= 1UL << 1,   // connect delegate has been called
	_kDidPassConnectMethod		= 1UL << 2,   // disconnection results in delegate call
	_kForbidStreamReadWrite		= 1UL << 3,   // no new reads or writes are allowed
	_kCloseSoon					= 1UL << 4,   // disconnect as soon as nothing is queued
};
typedef NSUInteger AFSocketConnectionFlags;

enum {
	_kStreamDidOpen			= 1UL << 0,
	_kStreamWillStartTLS	= 1UL << 1,
	_kStreamDidStartTLS		= 1UL << 2,
	_kStreamDequeuing		= 1UL << 3,
	_kStreamDidClose		= 1UL << 4,
};
typedef NSUInteger AFSocketConnectionStreamFlags;

NSSTRING_CONTEXT(AFNetworkTransportPacketQueueObservationContext);

@interface AFNetworkTransport ()
@property (assign) NSUInteger connectionFlags;
@property (readonly) CFReadStreamRef readStream;
@property (readonly) CFWriteStreamRef writeStream;
@property (assign) NSUInteger readFlags, writeFlags;
@property (readonly) AFPacketQueue *readQueue, *writeQueue;
@end

@interface AFNetworkTransport (Streams)
- (BOOL)_configureStreams;
- (void)_streamDidOpen;
- (void)_streamDidStartTLS;
@end

@interface AFNetworkTransport (PacketQueue)
- (void)_emptyQueues;

- (void)_tryDequeueReadPackets;
- (BOOL)_canDequeueReadPacket;
- (void)_readBytes;

- (void)_tryDequeueWritePackets;
- (BOOL)_canDequeueWritePacket;
- (void)_sendBytes;
@end

static void AFSocketConnectionReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo);
static void AFSocketConnectionWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo);

#pragma mark -

@implementation AFNetworkTransport

@dynamic delegate;
@synthesize connectionFlags=_connectionFlags;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_readInfo.queue = [[AFPacketQueue alloc] init];
	[_readInfo.queue addObserver:self forKeyPath:@"currentPacket" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:&AFNetworkTransportPacketQueueObservationContext];
	
	_writeInfo.queue = [[AFPacketQueue alloc] init];
	[_writeInfo.queue addObserver:self forKeyPath:@"currentPacket" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:&AFNetworkTransportPacketQueueObservationContext];
	
	return self;
}

- (id)initWithLowerLayer:(id <AFTransportLayer>)layer {
	self = [super initWithLowerLayer:layer];
	if (self == nil) return nil;
	
	AFNetworkSocket *networkSocket = (AFNetworkSocket *)layer;
	CFSocketRef socket = (CFSocketRef)[networkSocket socket];
	
	BOOL shouldCloseUnderlyingSocket = ((CFSocketGetSocketFlags(socket) & kCFSocketCloseOnInvalidate) == kCFSocketCloseOnInvalidate);
	if (shouldCloseUnderlyingSocket) CFSocketSetSocketFlags(socket, CFSocketGetSocketFlags(socket) & ~kCFSocketCloseOnInvalidate);
	
	_peer._hostDestination.host = (CFHostRef)NSMakeCollectable(CFRetain([(id)layer peer]));
	
	CFSocketNativeHandle nativeSocket = CFSocketGetNative(socket);
	CFSocketInvalidate(socket); // Note: the CFSocket must be invalidated for the CFStreams to capture the events
	
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocket, (CFReadStreamRef *)&_readInfo.stream, (CFWriteStreamRef *)&_writeInfo.stream);
	NSMakeCollectable(_writeInfo.stream);
	NSMakeCollectable(_readInfo.stream);
	
	// Note: ensure this is done in the same method as setting the socket options to essentially balance a retain/release on the native socket
	if (shouldCloseUnderlyingSocket) {
		CFWriteStreamSetProperty(self.writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
		CFReadStreamSetProperty(self.readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	}
	
	[self _configureStreams];
	
	return self;
}

- (id <AFConnectionLayer>)initWithNetService:(id <AFNetServiceCommon>)netService {
	self = [self init];
	if (self == nil) return nil;
	
	CFNetServiceRef *service = &_peer._netServiceDestination.netService;
	*service = (CFNetServiceRef)NSMakeCollectable(CFNetServiceCreate(kCFAllocatorDefault, (CFStringRef)[(id)netService valueForKey:@"domain"], (CFStringRef)[(id)netService valueForKey:@"type"], (CFStringRef)[(id)netService valueForKey:@"name"], 0));
	
	CFStreamCreatePairWithSocketToNetService(kCFAllocatorDefault, *service, (CFReadStreamRef *)&_readInfo.stream, (CFWriteStreamRef *)&_writeInfo.stream);
	NSMakeCollectable(_writeInfo.stream);
	NSMakeCollectable(_readInfo.stream);
	
	[self _configureStreams];
	
	return self;
}

- (id <AFConnectionLayer>)initWithPeerSignature:(const AFNetworkTransportPeerSignature *)signature {
	self = [self init];
	if (self == nil) return nil;
	
	memcpy(&_peer._hostDestination, signature, sizeof(AFNetworkTransportPeerSignature));
	
	CFHostRef *host = &_peer._hostDestination.host;
	*host = (CFHostRef)NSMakeCollectable(CFRetain(signature->host));
	
	CFStreamCreatePairWithSocketToCFHost(kCFAllocatorDefault, *host, _peer._hostDestination.transport->port, (CFReadStreamRef *)&_readInfo.stream, (CFWriteStreamRef *)&_writeInfo.stream);
	NSMakeCollectable(_writeInfo.stream);
	NSMakeCollectable(_readInfo.stream);
	
	[self _configureStreams];
	
	return self;
}

- (void)_close {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)finalize {
	if (![self isClosed]) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot finalize a layer which isn't closed yet.", __PRETTY_FUNCTION__, nil];
		return;
	}
	
	[self _close];
	
	[super finalize];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self close];
	[self _close];
	
	// Note: this will also release the netService if present
	CFHostRef *peer = &_peer._hostDestination.host; // Note: this is simply shorter to re-address, there is no fancyness, move along
	if (*peer != NULL) {
		CFRelease(*peer);
		*peer = NULL;
	}
	
	if (_readInfo.stream != NULL) {
		CFRelease(_readInfo.stream);
		_readInfo.stream = NULL;
	}
	[_readInfo.queue removeObserver:self forKeyPath:@"currentPacket"];
	[_readInfo.queue release];
	
	if (_writeInfo.stream != NULL) {
		CFRelease(_writeInfo.stream);
		_writeInfo.stream = NULL;
	}
	[_writeInfo.queue removeObserver:self forKeyPath:@"currentPacket"];
	[_writeInfo.queue release];
	
	[super dealloc];
}

- (CFReadStreamRef)readStream {
	return (CFReadStreamRef)_readInfo.stream;
}

- (NSUInteger)readFlags {
	return _readInfo.flags;
}

- (void)setReadFlags:(NSUInteger)value {
	_readInfo.flags = value;
}

- (AFPacketQueue *)readQueue {
	return _readInfo.queue;
}

- (CFWriteStreamRef)writeStream {
	return (CFWriteStreamRef)_writeInfo.stream;
}

- (NSUInteger)writeFlags {
	return _writeInfo.flags;
}

- (void)setWriteFlags:(NSUInteger)value {
	_writeInfo.flags = value;
}

- (AFPacketQueue *)writeQueue {
	return _writeInfo.queue;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &AFNetworkTransportPacketQueueObservationContext) {
		id oldPacket = [change objectForKey:NSKeyValueChangeOldKey];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketTimeoutNotificationName object:oldPacket];
		
		id newPacket = [change objectForKey:NSKeyValueChangeNewKey];
		if (newPacket == nil || [newPacket isEqual:[NSNull null]]) {
			if (object == self.writeQueue) {
				BOOL shouldClose = YES;
				shouldClose &= ((self.connectionFlags & _kCloseSoon) == _kCloseSoon);
				shouldClose &= ([self.writeQueue count] == 0);
				if (shouldClose) [self close];
			}
			
			return;
		}
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_packetTimeoutNotification:) name:AFPacketTimeoutNotificationName object:newPacket];
		[newPacket startTimeout];
		
		if (oldPacket == nil || [oldPacket isEqual:[NSNull null]]) {
			if (object == self.writeQueue) [self _tryDequeueWritePackets];
			if (object == self.readQueue) [self _tryDequeueReadPackets];
		}
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (CFTypeRef)peer {
	return _peer._hostDestination.host; // Note: this will also return the netService
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@" {\n"];
	
	[description appendFormat:@"\tPeer: %@\n", [(id)[self peer] description], nil];
	
	[description appendFormat:@"\tOpen: %@, Closed: %@\n", ([self isOpen] ? @"YES" : @"NO"), ([self isClosed] ? @"YES" : @"NO"), nil];
	
	[description appendFormat:@"\t%d pending reads, %d pending writes\n", [self.readQueue count], [self.writeQueue count], nil];
	
	static const char *StreamStatusStrings[] = { "not open", "opening", "open", "reading", "writing", "at end", "closed", "has error" };
	
	[description appendFormat:@"\tRead Stream: %p %s, ", self.readStream, (self.readStream != NULL ? StreamStatusStrings[CFReadStreamGetStatus(self.readStream)] : ""), nil];
	[description appendFormat:@"Current Read: %@", [self.readQueue currentPacket], nil];
	[description appendString:@"\n"];
	
	[description appendFormat:@"\tWrite Stream: %p %s, ", self.writeStream, (self.writeStream != NULL ? StreamStatusStrings[CFWriteStreamGetStatus(self.writeStream)] : ""), nil];	
	[description appendFormat:@"Current Write: %@", [self.writeQueue currentPacket], nil];
	[description appendString:@"\n"];
	
	if ((self.connectionFlags & _kCloseSoon) == _kCloseSoon) [description appendString: @"will close pending writes\n"];
	
	[description appendString:@"}"];
	
	return description;
}

- (void)scheduleInRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode {
	CFWriteStreamScheduleWithRunLoop(self.writeStream, loop, mode);
	CFReadStreamScheduleWithRunLoop(self.readStream, loop, mode);
}

- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode {
	CFWriteStreamUnscheduleFromRunLoop(self.writeStream, loop, mode);
	CFReadStreamUnscheduleFromRunLoop(self.readStream, loop, mode);
}

- (float)_packetProgress:(AFPacket *)packet bytesDone:(NSUInteger *)done bytesTotal:(NSUInteger *)total forTag:(NSUInteger *)tag {	
	if (tag != NULL) *tag = packet.tag;
	return (packet == nil ? NAN : [packet currentProgressWithBytesDone:done bytesTotal:total]);
}

- (float)currentReadProgressWithBytesDone:(NSUInteger *)done bytesTotal:(NSUInteger *)total forTag:(NSUInteger *)tag {
	return [self _packetProgress:[self.readQueue currentPacket] bytesDone:done bytesTotal:total forTag:tag];
}

- (float)currentWriteProgressWithBytesDone:(NSUInteger *)done bytesTotal:(NSUInteger *)total forTag:(NSUInteger *)tag {
	return [self _packetProgress:[self.writeQueue currentPacket] bytesDone:done bytesTotal:total forTag:tag];
}

#pragma mark -
#pragma mark Configuration

- (void)startTLS:(NSDictionary *)options {
	if (((self.readFlags & _kStreamWillStartTLS) == _kStreamWillStartTLS) ||
		((self.writeFlags & _kStreamWillStartTLS) == _kStreamWillStartTLS)) return;
	
	self.writeFlags = (self.writeFlags | _kStreamWillStartTLS);
	self.readFlags = (self.readFlags | _kStreamWillStartTLS);
	
	Boolean writeStreamResult = CFWriteStreamSetProperty(self.writeStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	Boolean readStreamResult = CFReadStreamSetProperty(self.readStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	
	if (!(readStreamResult && writeStreamResult)) {
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								  NSLocalizedStringWithDefaultValue(@"AFSocketConnectionTLSError", @"AFSocketConnection", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Couldn't start TLS, the connection will remain unsecure.", nil), NSLocalizedDescriptionKey,
								  nil];
		
		NSError *error = [NSError errorWithDomain:AFNetworkingErrorDomain code:AFSocketConnectionTLSError userInfo:userInfo];
		[self.delegate layer:self didNotStartTLS:error];
	}
}

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
		if ((self.connectionFlags & _kDidCallConnectDelegate) == _kDidCallConnectDelegate) return;
		
		[self.delegate layerDidOpen:self];
		return;
	}
	
	if (CFGetTypeID([self peer]) == CFHostGetTypeID()) {
		CFHostRef host = (CFHostRef)self.peer;
		
		CFStreamError error;
		memset(&error, 0, sizeof(CFStreamError));
		
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
			
			NSError *error = [NSError errorWithDomain:AFNetworkingErrorDomain code:AFSocketConnectionReachabilityError userInfo:userInfo];
			[self.delegate layer:self didNotOpen:error];
			
			return;
		}
	}
	
	Boolean result = true;
	result &= CFWriteStreamOpen(self.writeStream);
	result &= CFReadStreamOpen(self.readStream);
	if (result) return;
	
	[self close];
	[self.delegate layer:self didNotOpen:nil];
}

- (BOOL)isOpen {
	return (((self.readFlags & _kStreamDidOpen) == _kStreamDidOpen) && ((self.writeFlags & _kStreamDidOpen) == _kStreamDidOpen));
}

- (void)close {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(close) object:nil];
	
	// Note: you can only prevent a local close, if the streams were closed remotely there's nothing we can do
	if ((self.readFlags & _kStreamDidClose) != _kStreamDidClose && (self.writeFlags & _kStreamDidClose) != _kStreamDidClose) {
		// Note: if there are pending writes then the control delegate can keep the streams open
		if ([self.writeQueue currentPacket] != nil || [self.writeQueue count] > 0) {
			BOOL shouldRemainOpen = NO;
			if ([self.delegate respondsToSelector:@selector(socket:shouldRemainOpenPendingWrites:)])
				shouldRemainOpen = [self.delegate socket:self shouldRemainOpenPendingWrites:([self.writeQueue count] + 1)];
			
			if (shouldRemainOpen) {
				self.connectionFlags = (self.connectionFlags | (_kForbidStreamReadWrite | _kCloseSoon));
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
		
		self.readFlags = (self.readFlags | _kStreamDidClose);
	}
	
	if (self.writeStream != NULL) {
		if (streamError == nil) // Note: this guards against overwriting a non-nil error with a nil pointer
			streamError = [NSMakeCollectable(CFWriteStreamCopyError(self.writeStream)) autorelease];
		
		CFWriteStreamSetClient(self.writeStream, kCFStreamEventNone, NULL, NULL);
		CFWriteStreamClose(self.writeStream);
		
		self.writeFlags = (self.writeFlags | _kStreamDidClose);
	}
	
	self.connectionFlags = 0;
	
	if ([self.delegate respondsToSelector:@selector(layer:didDisconnectWithError:)])
		[self.delegate layer:self didDisconnectWithError:streamError];
	
	[self.delegate layerDidClose:self];
}

- (BOOL)isClosed {
	return (((self.readFlags & _kStreamDidClose) == _kStreamDidClose) && ((self.writeFlags & _kStreamDidClose) == _kStreamDidClose));
}

#pragma mark Reading

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	if ((self.connectionFlags & _kForbidStreamReadWrite) == _kForbidStreamReadWrite) return;
	NSParameterAssert(terminator != nil);
	
	AFPacketRead *packet = nil;
	if ([terminator isKindOfClass:[AFPacketRead class]]) {
		packet = terminator;
	} else {
		packet = [[[AFPacketRead alloc] initWithTag:tag timeout:duration terminator:terminator] autorelease];
	}
	
	[self.readQueue enqueuePacket:packet];
}

static void AFSocketConnectionReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFNetworkTransport *self = [[(AFNetworkTransport *)pInfo retain] autorelease];
	NSCParameterAssert(stream == self.readStream);
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			self.readFlags = (self.readFlags | _kStreamDidOpen);
			
			[self _streamDidOpen];
			break;
		}
		case kCFStreamEventHasBytesAvailable:
		{			
			if ((self.readFlags & _kStreamWillStartTLS) == _kStreamWillStartTLS && (self.readFlags & _kStreamDidStartTLS) != _kStreamDidStartTLS) {
				self.readFlags = (self.readFlags | _kStreamDidStartTLS);
				[self _streamDidStartTLS];
			} else [self _tryDequeueReadPackets];
			
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

#pragma mark Writing

- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration; {
	if ((self.connectionFlags & _kForbidStreamReadWrite) == _kForbidStreamReadWrite) return;
	if (data == nil || [data length] == 0) return;
	
	AFPacketWrite *packet = nil;
	if ([data isKindOfClass:[AFPacketWrite class]]) {
		packet = data;
	} else {
		packet = [[[AFPacketWrite alloc] initWithTag:tag timeout:duration data:data] autorelease];
	}
	
	[self.writeQueue enqueuePacket:packet];
}

static void AFSocketConnectionWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFNetworkTransport *self = [[(AFNetworkTransport *)pInfo retain] autorelease];
	NSCParameterAssert(stream == self.writeStream);
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			self.writeFlags = (self.writeFlags | _kStreamDidOpen);
			
			[self _streamDidOpen];
			break;
		}
		case kCFStreamEventCanAcceptBytes:
		{
			if ((self.writeFlags & _kStreamWillStartTLS) == _kStreamWillStartTLS && (self.writeFlags & _kStreamDidStartTLS) != _kStreamDidStartTLS) {
				self.writeFlags = (self.writeFlags | _kStreamDidStartTLS);
				[self _streamDidStartTLS];
			} else [self _tryDequeueWritePackets];
			
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

@end

#pragma mark -

@implementation AFNetworkTransport (Streams)

- (BOOL)_configureStreams {
	CFStreamClientContext context;
	memset(&context, 0, sizeof(CFStreamClientContext));
	context.info = self;
	
	CFStreamEventType sharedTypes = (kCFStreamEventOpenCompleted | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered);
	
	Boolean result = false;
	if (self.readStream != NULL) result |= CFReadStreamSetClient(self.readStream, (sharedTypes | kCFStreamEventHasBytesAvailable), AFSocketConnectionReadStreamCallback, &context);
	if (self.writeStream != NULL) result |= CFWriteStreamSetClient(self.writeStream, (sharedTypes | kCFStreamEventCanAcceptBytes), AFSocketConnectionWriteStreamCallback, &context);
	return result;
}

- (void)_streamDidOpen {
	if ((self.readFlags & _kStreamDidOpen) != _kStreamDidOpen || (self.writeFlags & _kStreamDidOpen) != _kStreamDidOpen) return;
	
	if ((self.connectionFlags & _kDidCallConnectDelegate) == _kDidCallConnectDelegate) return;
	self.connectionFlags = (self.connectionFlags | _kDidCallConnectDelegate);
	
	[self.delegate layerDidOpen:self];
	
	if ([self.delegate respondsToSelector:@selector(layer:didConnectToPeer:)])
		[self.delegate layer:self didConnectToPeer:(id)[self peer]];
	
	[self _tryDequeueWritePackets];
	[self _tryDequeueReadPackets];
}

- (void)_streamDidStartTLS {
	// FIXME: stream TLS start notifications need reconciling
	//if ((self.streamFlags & _kReadStreamDidStartTLS) != _kReadStreamDidStartTLS || (self.streamFlags & _kWriteStreamDidStartTLS) != _kWriteStreamDidStartTLS) return;
	
	if ([self.delegate respondsToSelector:@selector(layerDidStartTLS:)])
		[self.delegate layerDidStartTLS:self];
	
	[self _tryDequeueWritePackets];
	[self _tryDequeueReadPackets];
}

@end

#pragma mark -

@implementation AFNetworkTransport (PacketQueue)

- (void)_emptyQueues {
	[self.writeQueue emptyQueue];
	[self.readQueue emptyQueue];
}

- (void)_packetTimeoutNotification:(NSNotification *)notification {
	NSError *error = nil;
	
	if ([[notification object] isEqual:[self.readQueue currentPacket]]) {
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketConnectionReadTimeoutError", @"AFSocketConnection", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Read operation timeout.", nil), NSLocalizedDescriptionKey,
							  nil];
		
		error = [NSError errorWithDomain:AFNetworkingErrorDomain code:AFSocketConnectionReadTimeoutError userInfo:info];
	} else if ([[notification object] isEqual:[self.writeQueue currentPacket]]) {
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketConnectionWriteTimeoutError", @"AFSocketConnection", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Write operation timeout.", nil), NSLocalizedDescriptionKey,
							  nil];
		
		error = [NSError errorWithDomain:AFNetworkingErrorDomain code:AFSocketConnectionWriteTimeoutError userInfo:info];
	}
	
	[self.delegate layer:self didReceiveError:error];
}

#pragma mark -

- (void)_tryDequeueReadPackets {
	if (![self _canDequeueReadPacket]) return;
	
	self.readFlags = (self.readFlags | _kStreamDequeuing);
	
	do {
		[self _readBytes];
	} while ([self.readQueue tryDequeue]);
	
	self.readFlags = (self.readFlags & ~_kStreamDequeuing);
}

- (BOOL)_canDequeueReadPacket {
	if (self.readStream == NULL) return NO;
	if ((self.readFlags & _kStreamDequeuing) == _kStreamDequeuing) return NO;
	if (((self.readFlags & _kStreamWillStartTLS) == _kStreamWillStartTLS) && ((self.readFlags & _kStreamDidStartTLS) != _kStreamDidStartTLS)) return NO;
	return YES;
}

- (void)_readBytes {
	AFPacketRead *packet = [self.readQueue currentPacket];
	if (packet == nil || self.readStream == NULL) return;
	
	NSError *error = nil;
	BOOL packetComplete = [packet performRead:self.readStream error:&error];
	
	if (error != nil) {
		[self.delegate layer:self didReceiveError:error];
	}
	
	if ([self.delegate respondsToSelector:@selector(socket:didReadPartialDataOfLength:total:forTag:)]) {
		NSUInteger bytesRead = 0, bytesTotal = 0;
		[packet currentProgressWithBytesDone:&bytesRead bytesTotal:&bytesTotal];
		
		[self.delegate socket:self didReadPartialDataOfLength:bytesRead total:bytesTotal forTag:packet.tag];
	}
	
	if (!packetComplete) return;
		
	[self.delegate layer:self didRead:packet.buffer forTag:packet.tag];
	[self.readQueue dequeued];
}

#pragma mark -

- (void)_tryDequeueWritePackets {
	if (![self _canDequeueWritePacket]) return;
	
	self.writeFlags = (self.writeFlags | _kStreamDequeuing);
	
	do {
		[self _sendBytes];
	} while ([self.writeQueue tryDequeue]);
	
	self.writeFlags = (self.writeFlags & ~_kStreamDequeuing);
}

- (BOOL)_canDequeueWritePacket {
	if (self.writeStream == NULL) return NO;
	if ((self.writeFlags & _kStreamDequeuing) == _kStreamDequeuing) return NO;
	if (((self.writeFlags & _kStreamWillStartTLS) == _kStreamWillStartTLS) && ((self.writeFlags & _kStreamDidStartTLS) != _kStreamDidStartTLS)) return NO;
	return YES;
}

- (void)_sendBytes {
	AFPacketWrite *packet = [self.writeQueue currentPacket];
	if (packet == nil || self.writeStream == NULL) return;
	
	NSError *error = nil;
	BOOL packetComplete = [packet performWrite:self.writeStream error:&error];
	
	if (error != nil) {
		[self.delegate layer:self didReceiveError:error];
	}
	
	if ([self.delegate respondsToSelector:@selector(socket:didWritePartialDataOfLength:total:forTag:)]) {
		NSUInteger bytesWritten = 0, totalBytes = 0;
		[packet currentProgressWithBytesDone:&bytesWritten bytesTotal:&totalBytes];
		
		[self.delegate socket:self didWritePartialDataOfLength:bytesWritten total:totalBytes forTag:packet.tag];
	}
	
	if (!packetComplete) return;
	
	[self.delegate layer:self didWrite:packet.buffer forTag:packet.tag];
	[self.writeQueue dequeued];
}

@end
