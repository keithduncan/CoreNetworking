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
	_kReadStreamDidOpen			= 1UL << 0,
	_kReadStreamWillStartTLS	= 1UL << 1,
	_kReadStreamDidStartTLS		= 1UL << 2,
	_kReadStreamDidClose		= 1UL << 3,
	_kWriteStreamDidOpen		= 1UL << 4,
	_kWriteStreamWillStartTLS	= 1UL << 5,
	_kWriteStreamDidStartTLS	= 1UL << 6,
	_kWriteStreamDidClose		= 1UL << 7,
};
typedef NSUInteger AFSocketConnectionStreamFlags;

NSSTRING_CONTEXT(AFNetworkTransportPacketQueueObservationContext);

@interface AFNetworkTransport ()
@property (assign) NSUInteger connectionFlags;
@property (assign) NSUInteger streamFlags;
@property (retain) AFPacketQueue *readQueue, *writeQueue;
@end

@interface AFNetworkTransport (Streams)
- (BOOL)_configureStreams;
- (void)_streamDidOpen;
- (void)_streamDidStartTLS;
@end

@interface AFNetworkTransport (PacketQueue)
- (void)_emptyQueues;
- (void)_dequeuePackets;

- (BOOL)_canDequeueReadPacket;
- (void)_readBytes;
- (void)_endCurrentReadPacket;

- (BOOL)_canDequeueWritePacket;
- (void)_sendBytes;
- (void)_endCurrentWritePacket;
@end

static void AFSocketConnectionReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo);
static void AFSocketConnectionWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo);

#pragma mark -

@implementation AFNetworkTransport

@dynamic delegate;
@synthesize connectionFlags=_connectionFlags, streamFlags=_streamFlags;
@synthesize readQueue=_readQueue, writeQueue=_writeQueue;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	self.readQueue = [[[AFPacketQueue alloc] init] autorelease];
	[self.readQueue addObserver:self forKeyPath:@"currentPacket" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:&AFNetworkTransportPacketQueueObservationContext];
	
	self.writeQueue = [[[AFPacketQueue alloc] init] autorelease];
	[self.writeQueue addObserver:self forKeyPath:@"currentPacket" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:&AFNetworkTransportPacketQueueObservationContext];
	
	return self;
}

- (id)initWithLowerLayer:(id <AFTransportLayer>)layer {
	self = [super initWithLowerLayer:layer];
	if (self == nil) return nil;
	
	AFNetworkSocket *networkSocket = (AFNetworkSocket *)layer;
	CFSocketRef socket = (CFSocketRef)[networkSocket socket];
	
	CFSocketSetSocketFlags(socket, CFSocketGetSocketFlags(socket) & ~kCFSocketCloseOnInvalidate);
	
	_peer._hostDestination.host = (CFHostRef)NSMakeCollectable(CFRetain([(id)layer peer]));
	
	CFSocketNativeHandle nativeSocket = CFSocketGetNative(socket);
	CFSocketInvalidate(socket); // Note: the underlying CFSocket must be invalidated for the CFStreams to capture the events
	
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocket, &_readStream, &_writeStream);
	NSMakeCollectable(_readStream);
	NSMakeCollectable(_writeStream);
	
	// Note: ensure this is done in the same method as setting the socket options to essentially balance a retain/release on the native socket
	CFReadStreamSetProperty(_readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(_writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	
	[self _configureStreams];
	
	return self;
}

- (id <AFConnectionLayer>)initWithNetService:(id <AFNetServiceCommon>)netService {
	self = [self init];
	if (self == nil) return nil;
	
	CFNetServiceRef *service = &_peer._netServiceDestination.netService;
	*service = (CFNetServiceRef)NSMakeCollectable(CFNetServiceCreate(kCFAllocatorDefault, (CFStringRef)[(id)netService valueForKey:@"domain"], (CFStringRef)[(id)netService valueForKey:@"type"], (CFStringRef)[(id)netService valueForKey:@"name"], 0));
	
	CFStreamCreatePairWithSocketToNetService(kCFAllocatorDefault, *service, &_readStream, &_writeStream);
	NSMakeCollectable(_readStream);
	NSMakeCollectable(_writeStream);
	
	[self _configureStreams];
	
	return self;
}

- (id <AFConnectionLayer>)initWithPeerSignature:(const AFNetworkTransportPeerSignature *)signature {
	self = [self init];
	if (self == nil) return nil;
	
	memcpy(&_peer._hostDestination, signature, sizeof(AFNetworkTransportPeerSignature));
	
	CFHostRef *host = &_peer._hostDestination.host;
	*host = (CFHostRef)NSMakeCollectable(CFRetain(signature->host));
	
	CFStreamCreatePairWithSocketToCFHost(kCFAllocatorDefault, *host, _peer._hostDestination.transport->port, &_readStream, &_writeStream);
	NSMakeCollectable(_readStream);
	NSMakeCollectable(_writeStream);
	
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
	CFHostRef *host = &_peer._hostDestination.host; // Note: this is simply shorter to re-address, there is no fancyness, move along
	if (*host != NULL) {
		CFRelease(*host);
		*host = NULL;
	}
	
	if (_readStream != NULL) {
		CFRelease(_readStream);
		_readStream = NULL;
	}
	
	[_readQueue removeObserver:self forKeyPath:@"currentPacket"];
	[_readQueue release];
	
	if (_writeStream != NULL) {
		CFRelease(_writeStream);
		_writeStream = NULL;
	}
	
	[_writeQueue removeObserver:self forKeyPath:@"currentPacket"];
	[_writeQueue release];
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &AFNetworkTransportPacketQueueObservationContext) {
		id oldPacket = [change objectForKey:NSKeyValueChangeOldKey];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketTimeoutNotificationName object:oldPacket];
		
		id newPacket = [change objectForKey:NSKeyValueChangeNewKey];
		if (newPacket == nil) return;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_packetTimeoutNotification:) name:AFPacketTimeoutNotificationName object:newPacket];
		[newPacket startTimeout];
		
		if (object == self.readQueue)
			[self _readBytes];
		else if (object == self.writeQueue)
			[self _sendBytes];
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
	
	[description appendFormat:@"\tRead Stream: %p %s, ", _readStream, (_readStream != NULL ? StreamStatusStrings[CFReadStreamGetStatus(_readStream)] : ""), nil];
	[description appendFormat:@"Current Read: %@", [self.readQueue currentPacket], nil];
	[description appendString:@"\n"];
	
	[description appendFormat:@"\tWrite Stream: %p %s, ", _writeStream, (_writeStream != NULL ? StreamStatusStrings[CFWriteStreamGetStatus(_writeStream)] : ""), nil];	
	[description appendFormat:@"Current Write: %@", [self.writeQueue currentPacket], nil];
	[description appendString:@"\n"];
	
	if ((self.connectionFlags & _kCloseSoon) == _kCloseSoon) [description appendString: @"will close pending writes\n"];
	
	[description appendString:@"}"];
	
	return description;
}

- (void)scheduleInRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode {
	CFReadStreamScheduleWithRunLoop(_readStream, loop, mode);
	CFWriteStreamScheduleWithRunLoop(_writeStream, loop, mode);
}

- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode {
	CFReadStreamUnscheduleFromRunLoop(_readStream, loop, mode);
	CFWriteStreamUnscheduleFromRunLoop(_writeStream, loop, mode);
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
	if (((self.streamFlags & _kReadStreamWillStartTLS) == _kReadStreamWillStartTLS) ||
		((self.streamFlags & _kWriteStreamWillStartTLS) == _kWriteStreamWillStartTLS)) return;
	
	self.streamFlags = (self.streamFlags | (_kReadStreamWillStartTLS | _kWriteStreamWillStartTLS));
	
	Boolean _readStreamResult = CFReadStreamSetProperty(_readStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	Boolean _writeStreamResult = CFWriteStreamSetProperty(_writeStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	
	if (!(_readStreamResult && _writeStreamResult)) {
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
	if ([self isOpen]) return;
	
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
	result &= CFReadStreamOpen(_readStream);
	result &= CFWriteStreamOpen(_writeStream);
	if (result) return;
	
	[self close];
	[self.delegate layer:self didNotOpen:nil];
}

- (BOOL)isOpen {
	return (((self.streamFlags & _kReadStreamDidOpen) == _kReadStreamDidOpen) && ((self.streamFlags & _kWriteStreamDidOpen) == _kWriteStreamDidOpen));
}

- (void)close {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(close) object:nil];
	
	// Note: you can only prevent a local close, if the streams were closed remotely there's nothing we can do
	if ((self.streamFlags & _kReadStreamDidClose) != _kReadStreamDidClose && (self.streamFlags & _kWriteStreamDidClose) != _kWriteStreamDidClose) {
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
	
	[self _emptyQueues];
	
	NSError *streamError = nil;
	
	if (_readStream != NULL) {
		if (streamError == nil)
			streamError = [NSMakeCollectable(CFReadStreamCopyError(_readStream)) autorelease];
		
		CFReadStreamSetClient(_readStream, kCFStreamEventNone, NULL, NULL);
		CFReadStreamClose(_readStream);
		
		self.streamFlags = (self.streamFlags | _kReadStreamDidClose);
	}
	
	if (_writeStream != NULL) {
		if (streamError == nil) // Note: this guards against overwriting a non-nil error with a nil pointer
			streamError = [NSMakeCollectable(CFReadStreamCopyError(_readStream)) autorelease];
		
		CFWriteStreamSetClient(_writeStream, kCFStreamEventNone, NULL, NULL);
		CFWriteStreamClose(_writeStream);
		
		self.streamFlags = (self.streamFlags | _kWriteStreamDidClose);
	}
	
	self.connectionFlags = 0;
	
	if ([self.delegate respondsToSelector:@selector(layer:didDisconnectWithError:)])
		[self.delegate layer:self didDisconnectWithError:streamError];
	
	[self.delegate layerDidClose:self];
}

- (BOOL)isClosed {
	return (((self.streamFlags & _kReadStreamDidClose) == _kReadStreamDidClose) && ((self.streamFlags & _kWriteStreamDidClose) == _kWriteStreamDidClose));
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
	NSCParameterAssert(stream == self->_readStream);
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			self.streamFlags = (self.streamFlags | _kReadStreamDidOpen);
			
			[self _streamDidOpen];
			break;
		}
		case kCFStreamEventHasBytesAvailable:
		{
			if ((self.streamFlags & _kReadStreamWillStartTLS) == _kReadStreamWillStartTLS && (self.streamFlags & _kReadStreamDidStartTLS) != _kReadStreamDidStartTLS) {
				self.streamFlags = (self.streamFlags | _kReadStreamDidStartTLS);
				
				[self _streamDidStartTLS];
			} else {
				[self _readBytes];
			}
			
			break;
		}
		case kCFStreamEventErrorOccurred:
		{
			NSError *error = AFErrorFromCFStreamError(CFReadStreamGetError(self->_readStream));
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
	NSCParameterAssert(stream == self->_writeStream);
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			self.streamFlags = (self.streamFlags | _kWriteStreamDidOpen);
			
			[self _streamDidOpen];
			break;
		}
		case kCFStreamEventCanAcceptBytes:
		{
			if ((self.streamFlags & _kWriteStreamWillStartTLS) == _kWriteStreamWillStartTLS && (self.streamFlags & _kWriteStreamDidStartTLS) != _kWriteStreamDidStartTLS) {
				self.streamFlags = (self.streamFlags | _kWriteStreamDidStartTLS);
				
				[self _streamDidStartTLS];
			} else {
				[self _sendBytes];
			}
			
			break;
		}
		case kCFStreamEventErrorOccurred:
		{
			NSError *error = AFErrorFromCFStreamError(CFReadStreamGetError(self->_readStream));			
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
	
	Boolean result = true;
	if (_readStream != NULL) result &= CFReadStreamSetClient(_readStream, (sharedTypes | kCFStreamEventHasBytesAvailable), AFSocketConnectionReadStreamCallback, &context);
	if (_writeStream != NULL) result &= CFWriteStreamSetClient(_writeStream, (sharedTypes | kCFStreamEventCanAcceptBytes), AFSocketConnectionWriteStreamCallback, &context);
	return result;
}

- (void)_streamDidOpen {
	if ((self.streamFlags & _kReadStreamDidOpen) != _kReadStreamDidOpen || 
		(self.streamFlags & _kWriteStreamDidOpen) != _kWriteStreamDidOpen) return;
	
	if ((self.connectionFlags & _kDidCallConnectDelegate) == _kDidCallConnectDelegate) return;
	self.connectionFlags = (self.connectionFlags | _kDidCallConnectDelegate);
	
	[self.delegate layerDidOpen:self];
	
	if ([self.delegate respondsToSelector:@selector(layer:didConnectToPeer:)])
		[self.delegate layer:self didConnectToPeer:(id)[self peer]];
	
	[self _dequeuePackets];
}

- (void)_streamDidStartTLS {
	// FIXME: stream TLS start notifications need reconciling
	//if ((self.streamFlags & _kReadStreamDidStartTLS) != _kReadStreamDidStartTLS || (self.streamFlags & _kWriteStreamDidStartTLS) != _kWriteStreamDidStartTLS) return;
	
	if ([self.delegate respondsToSelector:@selector(layerDidStartTLS:)])
		[self.delegate layerDidStartTLS:self];
	
	[self _dequeuePackets];
}

@end

#pragma mark -

@implementation AFNetworkTransport (PacketQueue)

- (void)_emptyQueues {
	[self.readQueue emptyQueue];
	[self.writeQueue emptyQueue];
}

- (void)_dequeuePackets {
	if ([self _canDequeueReadPacket])
		[self.readQueue dequeuePacket];
	
	if ([self _canDequeueWritePacket])
		[self.writeQueue dequeuePacket];
}

- (void)_packetTimeoutNotification:(NSNotification *)notification {
	NSError *error = nil;
	
	if ([[notification object] isEqual:[self.readQueue currentPacket]]) {
		[self _endCurrentReadPacket];
		
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketConnectionReadTimeoutError", @"AFSocketConnection", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Read operation timeout.", nil), NSLocalizedDescriptionKey,
							  nil];
		
		error = [NSError errorWithDomain:AFNetworkingErrorDomain code:AFSocketConnectionReadTimeoutError userInfo:info];
	} else if ([[notification object] isEqual:[self.writeQueue currentPacket]]) {
		[self _endCurrentWritePacket];
		
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketConnectionWriteTimeoutError", @"AFSocketConnection", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Write operation timeout.", nil), NSLocalizedDescriptionKey,
							  nil];
		
		error = [NSError errorWithDomain:AFNetworkingErrorDomain code:AFSocketConnectionWriteTimeoutError userInfo:info];
	}
	
	[self.delegate layer:self didReceiveError:error];
}

#pragma mark -

- (BOOL)_canDequeueReadPacket {
	if (_readStream == NULL) return NO;
	if (((self.streamFlags & _kReadStreamWillStartTLS) == _kReadStreamWillStartTLS) && ((self.streamFlags & _kReadStreamDidStartTLS) != _kReadStreamDidStartTLS)) return NO;
	return (self.readQueue.currentPacket == nil);
}

- (void)_readBytes {
	AFPacketRead *packet = [self.readQueue currentPacket];
	if (packet == nil || _readStream == NULL) return;
	
	NSError *error = nil;
	BOOL packetComplete = [packet performRead:_readStream error:&error];
	
	if (error != nil) {
		[self.delegate layer:self didReceiveError:error];
	}
	
	if ([self.delegate respondsToSelector:@selector(socket:didReadPartialDataOfLength:total:forTag:)]) {
		NSUInteger bytesRead = 0, bytesTotal = 0;
		float percent = [packet currentProgressWithBytesDone:&bytesRead bytesTotal:&bytesTotal];
		
		[self.delegate socket:self didReadPartialDataOfLength:bytesRead total:bytesTotal forTag:packet.tag];
	}
	
	if (!packetComplete) return;
	
	// Note: the current packet is retained before calling the delegate so that it's still live even if we're not
	[[packet retain] autorelease];
	[self.delegate layer:self didRead:packet.buffer forTag:packet.tag];
	[self _endCurrentReadPacket];
}

- (void)_endCurrentReadPacket {	
	AFPacketRead *packet = [self.readQueue currentPacket];
	NSAssert(packet != nil, @"cannot complete a nil read packet");
	
	[self.readQueue dequeuePacket];
}

#pragma mark -

- (BOOL)_canDequeueWritePacket {
	if (_writeStream == NULL) return NO;
	if (((self.streamFlags & _kWriteStreamWillStartTLS) == _kWriteStreamWillStartTLS) && ((self.streamFlags & _kWriteStreamDidStartTLS) != _kWriteStreamDidStartTLS)) return NO;
	return (self.writeQueue.currentPacket == nil);
}

- (void)_sendBytes {
	AFPacketWrite *packet = [self.writeQueue currentPacket];
	if (packet == nil || _writeStream == NULL) return;
	
	NSError *error = nil;
	BOOL packetComplete = [packet performWrite:_writeStream error:&error];
	
	if (error != nil) {
		[self.delegate layer:self didReceiveError:error];
	}
	
	if ([self.delegate respondsToSelector:@selector(socket:didWritePartialDataOfLength:total:forTag:)]) {
		NSUInteger bytesWritten = 0, totalBytes = 0;
		float percent =	[packet currentProgressWithBytesDone:&bytesWritten bytesTotal:&totalBytes];
		
		[self.delegate socket:self didWritePartialDataOfLength:bytesWritten total:totalBytes forTag:packet.tag];
	}
	
	if (!packetComplete) return;
	
	// Note: the current packet is retained before calling the delegate so that it's still live even if we're not
	[[packet retain] autorelease];
	[self.delegate layer:self didWrite:packet.buffer forTag:packet.tag];
	[self _endCurrentWritePacket];
}

- (void)_endCurrentWritePacket {	
	AFPacketWrite *packet = [self.writeQueue currentPacket];
	NSAssert(packet != nil, @"cannot complete a nil write packet");
	
	[self.writeQueue dequeuePacket];
	
	// Note: it is important that this comes after the dequeue so that the current packet can be nil for comparison
	BOOL shouldClose = ((self.connectionFlags & _kCloseSoon) == _kCloseSoon);
	shouldClose &= (([self.writeQueue count] == 0) && ([self.writeQueue currentPacket] == nil));
	if (shouldClose) [self close];
}

@end
