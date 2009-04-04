//
//  AFSocket.m
//
//	Originally based on AsyncSocket http://code.google.com/p/cocoaasyncsocket/
//		Although the code is much departed from the original codebase
//
//  Created by Keith Duncan
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFSocketConnection.h"

#import <sys/socket.h>
#import <arpa/inet.h>
#import <netdb.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

#import "AFSocket.h"
#import "AFNetworkConstants.h"
#import "AFNetworkFunctions.h"

#import "AFPacketRead.h"
#import "AFPacketWrite.h"

enum {
	_kEnablePreBuffering		= 1UL << 0,   // pre-buffering is enabled.
	_kDidCallConnectDelegate	= 1UL << 1,   // connect delegate has been called.
	_kDidPassConnectMethod		= 1UL << 2,   // disconnection results in delegate call.
	_kForbidStreamReadWrite		= 1UL << 3,   // no new reads or writes are allowed.
	_kCloseSoon					= 1UL << 4,   // disconnect as soon as nothing is queued.
	_kClosingWithError			= 1UL << 5,   // the socket is being closed due to an error.
};
typedef NSUInteger AFSocketConnectionFlags;

enum {
	_kReadStreamDidOpen			= 1UL << 0,
	_kReadStreamDidClose		= 1UL << 1,
	_kWriteStreamDidOpen		= 1UL << 2,
	_kWriteStreamDidClose		= 1UL << 3,
};
typedef NSUInteger AFSocketConnectionStreamFlags;

@interface AFSocketConnection ()
@property (assign) NSUInteger connectionFlags;
@property (assign) NSUInteger streamFlags;
@property (retain) AFPacketRead *currentReadPacket;
@property (retain) AFPacketWrite *currentWritePacket;
@end

@interface AFSocketConnection (Streams)
- (void)_streamDidOpen;
@end

@interface AFSocketConnection (PacketQueue)
- (void)_emptyQueues;

- (void)_enqueueReadPacket:(id)packet;
- (void)_dequeueReadPacket;
- (void)_readBytes;
- (void)_endCurrentReadPacket;

- (void)_enqueueWritePacket:(id)packet;
- (void)_dequeueWritePacket;
- (void)_sendBytes;
- (void)_endCurrentWritePacket;
@end

static void AFSocketConnectionReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo);
static void AFSocketConnectionWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo);

#pragma mark -

@implementation AFSocketConnection

@synthesize lowerLayer;
@synthesize delegate=_delegate;
@synthesize connectionFlags=_connectionFlags, streamFlags=_streamFlags;
@synthesize currentReadPacket=_currentReadPacket, currentWritePacket=_currentWritePacket;

- (id)initWithLowerLayer:(id <AFNetworkLayer>)layer delegate:(id <AFSocketConnectionControlDelegate, AFSocketConnectionDataDelegate>)delegate {
	self = [self init];
	
	lowerLayer = [layer retain];
	
	CFSocketRef socket = ((CFSocketRef)[(AFSocket *)layer lowerLayer]);
	CFSocketSetSocketFlags(socket, (CFSocketGetSocketFlags(socket) & ~kCFSocketCloseOnInvalidate));
	CFDataRef peerAddress = CFSocketCopyPeerAddress(socket);
	
	CFHostRef host = CFHostCreateWithAddress(kCFAllocatorDefault, peerAddress);
	_peer._hostDestination.host = (CFHostRef)CFRetain(host);
	CFRelease(host);
	
	CFSocketNativeHandle sock = CFSocketGetNative(socket);
	CFSocketInvalidate(socket);
	
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, sock, &readStream, &writeStream);
	
	CFStreamClientContext context;
	memset(&context, 0, sizeof(CFStreamClientContext));
	context.info = self;
	
	Boolean result = NO;
	
	CFStreamEventType types = (kCFStreamEventOpenCompleted | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered);
	result = CFReadStreamSetClient(readStream, (types | kCFStreamEventHasBytesAvailable), AFSocketConnectionReadStreamCallback, &context);
	result = CFWriteStreamSetClient(writeStream, (types | kCFStreamEventCanAcceptBytes), AFSocketConnectionWriteStreamCallback, &context);
	
	_delegate = delegate;
	
	return self;
}

/*
	The layout of the _peer union members is important, we can cast the _peer instance variable to CFTypeRef and introspect using CFGetTypeID to determine the member in use
 */

- (id <AFConnectionLayer>)initWithNetService:(id <AFNetServiceCommon>)netService {
	self = [self init];
	
	CFNetServiceRef *service = _peer._netServiceDestination.netService;
	
	*service = CFNetServiceCreate(kCFAllocatorDefault, [netService valueForKey:@"domain"], <#CFStringRef serviceType#>, <#CFStringRef name#>, <#SInt32 port#>)
	 = CFNetServiceCreate(kCFAllocatorDefault, <#CFStringRef domain#>, <#CFStringRef serviceType#>, <#CFStringRef name#>, <#SInt32 port#>)
	
	CFStreamCreatePairWithSocketToNetService(kCFAllocatorDefault, <#CFNetServiceRef service#>, <#CFReadStreamRef * readStream#>, <#CFWriteStreamRef * writeStream#>)
	
	return self;
}

- (id <AFConnectionLayer>)initWithSignature:(const AFSocketSignature *)signature {
	self = [self init];
	
	CFHostRef *host = &_peer._hostDestination.host;
	
	*host = CFRetain(signature->host);
	CFStreamCreatePairWithSocketToCFHost(kCFAllocatorDefault, *host, signature->transport.port, &readStream, &writeStream);
	
	return self;
}

- (id)init {
	self = [super init];
	
	readQueue = [[NSMutableArray alloc] init];	
	writeQueue = [[NSMutableArray alloc] init];
	
	return self;
}

- (void)dealloc {
	[lowerLayer release];
	
	// Note: this will also deallocate the netService if it is used instead
	CFHostRef *host = &_peer._hostDestination.host; // Note: this is simply shorter to re-address, there is no fancyness, move along
	if (*host != NULL) {
		CFRelease(*host);
		*host = NULL;
	}
	
	if (readStream != NULL) {
		CFRelease(readStream);
		readStream = NULL;
	}
	[readQueue release];
	[_currentReadPacket release];
	
	if (writeStream != NULL) {
		CFRelease(writeStream);
		writeStream = NULL;
	}
	[writeQueue release];
	[_currentWritePacket release];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self.delegate selector:@selector(layerDidClose:) object:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[super dealloc];
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@"\n"];
	
	[description appendFormat:@"\tOpen: %@, Closed: %@", ([self isOpen] ? @"YES" : @"NO"), ([self isClosed] ? @"YES" : @"NO"), nil];
	[description appendString:@"\n"];
	
	if ([self isOpen]) {
		[description appendString:@"\tPeer: "];
		[description appendFormat:@"%@", [(id)_peer._hostDestination.host description], nil];
		[description appendString:@"\n"];
	}
	
	[description appendFormat:@"\t%d pending reads, %d pending writes", [readQueue count], [writeQueue count], nil];
	[description appendString:@"\n"];
	
	AFPacketRead *readPacket = [self currentReadPacket];
	[description appendFormat:@"\tCurrent Read: %@", readPacket, nil];
	[description appendString:@"\n"];
	
	AFPacketWrite *writePacket = [self currentWritePacket];
	[description appendFormat:@"\tCurrent Read: %@", writePacket, nil];
	[description appendString:@"\n"];
	
	{
		static const char *StreamStatusStrings[] = { "not open", "opening", "open", "reading", "writing", "at end", "closed", "has error" };
		[description appendFormat:@"\tRead Stream: %p %s, ", readStream, (readStream != NULL ? StreamStatusStrings[CFReadStreamGetStatus(readStream)] : ""), nil];
		[description appendFormat:@"\tWrite Stream: %p %s, ", writeStream, (writeStream != NULL ? StreamStatusStrings[CFWriteStreamGetStatus(writeStream)] : ""), nil];	
		
		if ((self.connectionFlags & _kCloseSoon) == _kCloseSoon) [description appendString: @"will close pending writes, "];
	}
	[description appendString:@"\n"];
	
	return description;
}

- (void)scheduleInRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode {
	CFReadStreamScheduleWithRunLoop(readStream, loop, mode);
	CFWriteStreamScheduleWithRunLoop(writeStream, loop, mode);
}

- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode {
	CFReadStreamUnscheduleFromRunLoop(readStream, loop, mode);
	CFWriteStreamUnscheduleFromRunLoop(writeStream, loop, mode);
}

- (void)_packet:(AFPacket *)packet progress:(float *)fraction bytesDone:(NSUInteger *)done total:(NSUInteger *)total forTag:(NSUInteger *)tag {
	if (packet == nil) {
		if (fraction != NULL) *fraction = NAN;
		return;
	}
	
	if (tag != NULL) *tag = packet.tag;
	[packet progress:fraction done:done total:total];
}

- (void)currentReadProgress:(float *)fraction bytesDone:(NSUInteger *)done total:(NSUInteger *)total forTag:(NSUInteger *)tag {
	[self _packet:[self currentReadPacket] progress:fraction bytesDone:done total:total forTag:tag];
}

- (void)currentWriteProgress:(float *)fraction bytesDone:(NSUInteger *)done total:(NSUInteger *)total forTag:(NSUInteger *)tag {
	[self _packet:[self currentWritePacket] progress:fraction bytesDone:done total:total forTag:tag];
}

#pragma mark -
#pragma mark Configuration

- (BOOL)startTLS:(NSDictionary *)options {
	Boolean value = true;
	value &= CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	value &= CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	return (BOOL)value;
}

#pragma mark -
#pragma mark Connection

- (void)open {
	Boolean result = NO;
	result = CFReadStreamOpen(readStream);
	result = CFWriteStreamOpen(writeStream);
}

- (BOOL)isOpen {
	return (((self.streamFlags & _kReadStreamDidOpen) == _kReadStreamDidOpen) && ((self.streamFlags & _kWriteStreamDidOpen) == _kWriteStreamDidOpen));
}

- (void)close {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(close) object:nil];
	
	// Note: you can only prevent a local close, if the streams were closed remotely there's nothing we can do
	if ((self.streamFlags & _kReadStreamDidClose) != _kReadStreamDidClose && (self.streamFlags & _kWriteStreamDidClose) != _kWriteStreamDidClose) {
		// Note: if there are pending writes then the control delegate can keep the streams open
		if (self.currentWritePacket != nil || [writeQueue count] > 0) {
			BOOL shouldRemainOpen = NO;
			if ([self.delegate respondsToSelector:@selector(socket:shouldRemainOpenPendingWrites:)])
				shouldRemainOpen = [self.delegate socket:self shouldRemainOpenPendingWrites:([writeQueue count] + 1)];
			
			if (shouldRemainOpen) {
				self.connectionFlags = (self.connectionFlags | (_kForbidStreamReadWrite | _kCloseSoon));
				return;
			}
		}
	}
	
	[self _emptyQueues];
	
	if (readStream != NULL) {
		CFReadStreamSetClient(readStream, kCFStreamEventNone, NULL, NULL);
		CFReadStreamClose(readStream);
	}
	
	if (writeStream != NULL) {
		CFWriteStreamSetClient(writeStream, kCFStreamEventNone, NULL, NULL);
		CFWriteStreamClose(writeStream);
	}
	
	self.streamFlags = 0;
	
	BOOL notifyDelegate = ((self.connectionFlags & _kDidPassConnectMethod) == _kDidPassConnectMethod);
	
	// Note: clear the flags, self could be reused?
	// Note: clear the flags before calling the delegate as it could release self
	self.connectionFlags = 0;
	
	if (notifyDelegate && [self.delegate respondsToSelector:@selector(layerDidClose:)]) {
		[self.delegate layerDidClose:self];
	}
}

- (BOOL)isClosed {
	return (((self.streamFlags & _kReadStreamDidClose) == _kReadStreamDidClose) && ((self.streamFlags & _kWriteStreamDidClose) == _kWriteStreamDidClose));
}

#pragma mark Termination

- (void)disconnectWithError:(NSError *)error {
	if (error != nil) {
		self.connectionFlags = (self.connectionFlags | _kClosingWithError);
		
		if ((self.connectionFlags & _kDidPassConnectMethod) == _kDidPassConnectMethod) {
			if ([self.delegate respondsToSelector:@selector(layer:didDisconnectWithError:)])
				[self.delegate layer:self didDisconnectWithError:error];
		}
	}
	
	[self close];
}

#pragma mark Reading

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	if ((self.connectionFlags & _kForbidStreamReadWrite) == _kForbidStreamReadWrite) return;
	NSParameterAssert(terminator != nil);
	
	AFPacketRead *packet = [[AFPacketRead alloc] initWithTag:tag timeout:duration terminator:terminator];
	[self _enqueueReadPacket:packet];
	[packet release];
	
	[self performSelector:@selector(_dequeueReadPacket) withObject:nil afterDelay:0.0];
}

static void AFSocketConnectionReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFSocketConnection *self = [[(AFSocketConnection *)pInfo retain] autorelease];
	NSCParameterAssert(stream == self->readStream);
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			self.streamFlags = (self.streamFlags | _kReadStreamDidOpen);
			
			[self _streamDidOpen];
			break;
		}
		case kCFStreamEventHasBytesAvailable:
		{
			[self _readBytes];
			break;
		}
		case kCFStreamEventErrorOccurred:
		{
			NSError *error = AFErrorFromCFStreamError(CFReadStreamGetError(self->readStream));
			
			if ([self.delegate respondsToSelector:@selector(socket:didReceiveError:)])
				[self.delegate socket:self didReceiveError:error];
			
			break;
		}
		case kCFStreamEventEndEncountered:
		{
			self.streamFlags = (self.streamFlags | _kReadStreamDidClose);
			
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
	
	AFPacketWrite *packet = [[AFPacketWrite alloc] initWithTag:tag timeout:duration data:data];
	[self _enqueueWritePacket:packet];
	[packet release];
	
	[self performSelector:@selector(_dequeueWritePacket) withObject:nil afterDelay:0.0];
}

static void AFSocketConnectionWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFSocketConnection *self = [[(AFSocketConnection *)pInfo retain] autorelease];
	NSCParameterAssert(stream == self->writeStream);
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			self.streamFlags = (self.streamFlags | _kWriteStreamDidOpen);
			
			[self _streamDidOpen];
			break;
		}
		case kCFStreamEventCanAcceptBytes:
		{
			[self _sendBytes];
			break;
		}
		case kCFStreamEventErrorOccurred:
		{
			NSError *error = AFErrorFromCFStreamError(CFReadStreamGetError(self->readStream));
			
			if ([self.delegate respondsToSelector:@selector(socket:didReceiveError:)])
				[self.delegate socket:self didReceiveError:error];
			
			break;
		}
		case kCFStreamEventEndEncountered:
		{
			self.streamFlags = (self.streamFlags | _kWriteStreamDidClose);
			
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

@implementation AFSocketConnection (Streams)

- (void)_streamDidOpen {
	if ((self.streamFlags & _kReadStreamDidOpen) != _kReadStreamDidOpen || 
		(self.streamFlags & _kWriteStreamDidOpen) != _kWriteStreamDidOpen) return;
	
	if ((self.connectionFlags & _kDidCallConnectDelegate) == _kDidCallConnectDelegate) return;
	self.connectionFlags = (self.connectionFlags | _kDidCallConnectDelegate);
	
	if ([self.delegate respondsToSelector:@selector(layer:didConnectToPeer:)])
		[self.delegate layer:self didConnectToPeer:_peer._hostDestination.host];
	
	if ([self.delegate respondsToSelector:@selector(layerDidOpen:)])
		[self.delegate layerDidOpen:self];
	
	[self performSelector:@selector(_dequeueReadPacket) withObject:nil afterDelay:0.0];
	[self performSelector:@selector(_dequeueWritePacket) withObject:nil afterDelay:0.0];
}

@end

#pragma mark -

@implementation AFSocketConnection (Private)

- (void)_emptyQueues {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_dequeueWritePacket) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_dequeueReadPacket) object:nil];
	
	if ([self currentWritePacket] != nil) [self _endCurrentWritePacket];
	[writeQueue removeAllObjects];
	
	if ([self currentReadPacket] != nil) [self _endCurrentReadPacket];
	[readQueue removeAllObjects];
}

- (void)_packetTimeoutNotification:(NSNotification *)notification {	
	if ([[notification object] isEqual:[self currentReadPacket]]) {
		[self _endCurrentReadPacket];
		
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketStreamReadTimeoutError", @"AFSocketStream", [NSBundle mainBundle], @"Read operation timeout", nil), NSLocalizedDescriptionKey,
							  nil];
		
		NSError *error = [NSError errorWithDomain:AFNetworkingErrorDomain code:AFSocketConnectionReadTimeoutError userInfo:info];
		
		if ([self.delegate respondsToSelector:@selector(socket:didReceiveError:)])
			[self.delegate socket:self didReceiveError:error];
	} else if ([[notification object] isEqual:[self currentWritePacket]]) {
		[self _endCurrentWritePacket];
		
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketStreamWriteTimeoutError", @"AFSocketStream", [NSBundle mainBundle], @"Write operation timeout", nil), NSLocalizedDescriptionKey,
							  nil];
		
		NSError *error = [NSError errorWithDomain:AFNetworkingErrorDomain code:AFSocketConnectionWriteTimeoutError userInfo:info];
			
		if ([self.delegate respondsToSelector:@selector(socket:didReceiveError:)])
			[self.delegate socket:self didReceiveError:error];
	}
}

#pragma mark -

- (void)_enqueueReadPacket:(id)packet {
	[readQueue addObject:packet];
}

- (void)_dequeueReadPacket {
	if (readStream == NULL) return;
	AFPacketRead *packet = [self currentReadPacket];
	if (packet != nil) return;
	
	if ([readQueue count] > 0) {
		self.currentReadPacket = [readQueue objectAtIndex:0];
		[readQueue removeObjectAtIndex:0];
	}
	
	packet = [self currentReadPacket];
	if (packet == nil) return;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_packetTimeoutNotification:) name:AFPacketTimeoutNotificationName object:packet];
	[packet startTimeout];
	
	[self _readBytes];
}

#warning the _readBytes and _sendBytes methods are identical with exception to the selector names called, the packet architecture could be further condensed into a packet queue class

- (void)_readBytes {
	AFPacketRead *packet = [self currentReadPacket];
	if (packet == nil || readStream == NULL) return;
	
	NSError *error = nil;
	BOOL packetComplete = [packet performRead:readStream error:&error];
	
	if (error != nil) {
		if ([self.delegate respondsToSelector:@selector(socket:didReceiveError:)])
			[self.delegate socket:self didReceiveError:error];
	}
	
	if ([self.delegate respondsToSelector:@selector(socket:didReadPartialDataOfLength:tag:)]) {
		float percent = 0.0;
		NSUInteger bytesRead = 0;
		
		[packet progress:&percent done:&bytesRead total:NULL];
		
		[self.delegate socket:self didReadPartialDataOfLength:bytesRead tag:packet.tag];
	}
	
	if (packetComplete) {
#warning for packets with a terminator we need to cache the data after the terminator for future reads
		
		if ([self.delegate respondsToSelector:@selector(layer:didRead:forTag:)])
			[self.delegate layer:self didRead:packet.buffer forTag:packet.tag];
		
		[self _endCurrentReadPacket];
	}
}

- (void)_endCurrentReadPacket {
	AFPacketRead *packet = [self currentReadPacket];
	NSAssert(packet != nil, @"cannot complete a nil read packet");
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketTimeoutNotificationName object:packet];
	
	self.currentReadPacket = nil;
	
	[self performSelector:@selector(_dequeueReadPacket) withObject:nil afterDelay:0.0];
}

#pragma mark -

- (void)_enqueueWritePacket:(id)packet {
	[writeQueue addObject:packet];
}

- (void)_dequeueWritePacket {
	if (writeStream == NULL) return;
	AFPacketWrite *packet = [self currentWritePacket];
	if (packet != nil) return;
	
	if ([writeQueue count] > 0) {
		[self setCurrentWritePacket:[writeQueue objectAtIndex:0]];
		[writeQueue removeObjectAtIndex:0];
	}
	
	packet = [self currentWritePacket];
	if (packet == nil) return;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_packetTimeoutNotification:) name:AFPacketTimeoutNotificationName object:packet];
	[packet startTimeout];
	
	[self _sendBytes];
}

- (void)_sendBytes {
	AFPacketWrite *packet = [self currentWritePacket];
	if (packet == nil || writeStream == NULL) return;
	
	NSError *error = nil;
	BOOL packetComplete = [packet performWrite:writeStream error:&error];
	
	if (error != nil) {
		if ([self.delegate respondsToSelector:@selector(socket:didReceiveError:)])
			[self.delegate socket:self didReceiveError:error];
	}
	
	if ([self.delegate respondsToSelector:@selector(socket:didWritePartialDataOfLength:tag:)]) {
		float percent = 0.0;
		NSUInteger bytesWritten = 0;
		
		[packet progress:&percent done:&bytesWritten total:NULL];
		
		[self.delegate socket:self didWritePartialDataOfLength:bytesWritten tag:packet.tag];
	}
	
	if (packetComplete) {
		if ([self.delegate respondsToSelector:@selector(layer:didWrite:forTag:)])
			[self.delegate layer:self didWrite:packet.buffer forTag:packet.tag];
		
		[self _endCurrentWritePacket];
	}
}

- (void)_endCurrentWritePacket {
	AFPacketWrite *packet = [self currentWritePacket];
	NSAssert(packet != nil, @"cannot complete a nil write packet");
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketTimeoutNotificationName object:packet];
	
	self.currentWritePacket = nil;
	
	[self performSelector:@selector(_dequeueWritePacket) withObject:nil afterDelay:0.0];
	
	if ((self.connectionFlags & _kCloseSoon) != _kCloseSoon) return;
	if (([writeQueue count] != 0) || ([self currentWritePacket] != nil)) return;
	
	[self close];
}

@end
