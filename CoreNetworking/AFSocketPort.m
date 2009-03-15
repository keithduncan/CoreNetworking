//
//  AFSocket.m
//
//	Originally based on AsyncSocket http://code.google.com/p/cocoaasyncsocket/
//
//  Created by Keith Duncan
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFSocketPort.h"

#import <sys/socket.h>
#import <arpa/inet.h>
#import <netdb.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

#import "AFPacketRead.h"
#import "AFPacketWrite.h"

struct AFSocketType AFSocketTypeTCP = {.socketType = SOCK_STREAM, .protocol = IPPROTO_TCP};
struct AFSocketType AFSocketTypeUDP = {.socketType = SOCK_DGRAM, .protocol = IPPROTO_UDP};

#define READQUEUE_CAPACITY	5           // Initial capacity
#define WRITEQUEUE_CAPACITY 5           // Initial capacity

enum {
	_kEnablePreBuffering		= 1UL << 0,   // pre-buffering is enabled.
	_kDidCallConnectDelegate	= 1UL << 1,   // connect delegate has been called.
	_kDidPassConnectMethod		= 1UL << 2,   // disconnection results in delegate call.
	_kForbidStreamReadWrite		= 1UL << 3,   // no new reads or writes are allowed.
	_kCloseSoon					= 1UL << 4,   // disconnect as soon as nothing is queued.
	_kClosingWithError			= 1UL << 5,   // the socket is being closed due to an error.
};
typedef NSUInteger AFSocketPortFlags;

@interface AFSocketPort ()
@property (assign) NSUInteger portFlags;
@property (retain) AFPacketRead *currentReadPacket;
@property (retain) AFPacketWrite *currentWritePacket;
@end

@interface AFSocketPort (PacketQueue)
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

static void AFSocketReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo);
static void AFSocketWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo);

#pragma mark -

@implementation AFSocketPort

@synthesize delegate=_delegate;
@synthesize portFlags=_portFlags;

@synthesize hostDelegate=_delegate;

@synthesize currentReadPacket=_currentReadPacket, currentWritePacket=_currentWritePacket;

- (id)init {
	[super init];
	
	readQueue = [[NSMutableArray alloc] initWithCapacity:READQUEUE_CAPACITY];	
	writeQueue = [[NSMutableArray alloc] initWithCapacity:WRITEQUEUE_CAPACITY];
	
	return self;
}

- (void)dealloc {
	CFSocketInvalidate(_socket);
	
	CFRelease(_socketRunLoopSource);
	CFRelease(_socket);
	
	[_currentReadPacket release];
	[readQueue release];
		
	[_currentWritePacket release];
	[writeQueue release];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self.delegate selector:@selector(layerDidClose:) object:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[super dealloc];
}

+ (id <AFNetworkLayer>)peerWithNetService:(id <AFNetServiceCommon>)netService {
	AFSocketPort *socket = [[self alloc] init];
	
	return socket;
}

+ (id <AFNetworkLayer>)peerWithSignature:(const AFSocketSignature *)signature {
	AFSocketPort *socket = [[self alloc] init];
	
	return socket;
}

- (BOOL)canSafelySetDelegate {
	return ([readQueue count] == 0 && [writeQueue count] == 0 && [self currentReadPacket] == nil && [self currentWritePacket] == nil);
}

- (void)currentReadProgress:(float *)fraction bytesDone:(NSUInteger *)done total:(NSUInteger *)total tag:(NSUInteger *)tag {
	AFPacketRead *packet = [self currentReadPacket];
	
	if (packet == nil) {
		if (fraction != NULL) *fraction = NAN;
		return;
	}
	
	if (tag != NULL) *tag = packet.tag;
	[packet progress:fraction done:done total:total];
}

- (void)currentWriteProgress:(float *)fraction bytesDone:(NSUInteger *)done total:(NSUInteger *)total tag:(NSUInteger *)tag {
	AFPacketWrite *packet = [self currentWritePacket];
	
	if (packet == nil) {
		if (fraction != NULL) *fraction = NAN;
		return;
	}
	
	if (tag != NULL) *tag = packet.tag;
	[packet progress:fraction done:done total:total];
}

#pragma mark Configuration

- (BOOL)startTLS:(NSDictionary *)options {
	Boolean value = true;
	value &= CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	value &= CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	return (value == true ? YES : NO);
}

#pragma mark Connection

- (void)open {
	
}

- (BOOL)isOpen {
	return ((self.portFlags & _kDidPassConnectMethod) == _kDidPassConnectMethod);
}

- (void)close {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(close) object:nil];
	
	if ((self.portFlags & _kCloseSoon) != _kCloseSoon) {
		BOOL shouldRemainOpen = NO;
		
		if ([self.delegate respondsToSelector:@selector(socketShouldRemainOpenPendingWrites:)])
			[self.delegate socketShouldRemainOpenPendingWrites:self];
		
		if (shouldRemainOpen) {
			self.portFlags = (self.portFlags | (_kForbidStreamReadWrite | _kCloseSoon));
			return;
		}
	}
	
	[self _emptyQueues];
	
	if (readStream != NULL) {
		CFReadStreamSetClient(readStream, kCFStreamEventNone, NULL, NULL);
		CFReadStreamClose(readStream);
		
		CFRelease(readStream);
		readStream = NULL;
	}
	
	if (writeStream != NULL) {
		CFWriteStreamSetClient(writeStream, kCFStreamEventNone, NULL, NULL);
		CFWriteStreamClose(writeStream);
		
		CFRelease(writeStream);
		writeStream = NULL;
	}
	
	
	if (_socket != NULL) {
		CFSocketInvalidate(_socket);
		
		CFRelease(_socket);
		_socket = NULL;
	}
	
	if (_socketRunLoopSource != NULL) {
		CFRunLoopRemoveSource(_runLoop, _socketRunLoopSource, kCFRunLoopDefaultMode);
		
		CFRelease(_socketRunLoopSource);
		_socketRunLoopSource = NULL;
	}
	
	_runLoop = NULL;
	
	BOOL notifyDelegate = ((self.portFlags & _kDidPassConnectMethod) == _kDidPassConnectMethod);
	
	// Note: clear the flags, self could be reused
	// Note: clear the flags before calling the delegate as it could release self
	self.portFlags = 0;
	
	if (notifyDelegate && [self.delegate respondsToSelector:@selector(layerDidClose:)]) {
		[self.delegate layerDidClose:self];
	}
}

- (BOOL)isClosed {
	return (self.portFlags == 0);
}

#pragma mark Termination

- (void)disconnectWithError:(NSError *)error {
	self.portFlags = (self.portFlags | _kClosingWithError);
	
	if ((self.portFlags & _kDidPassConnectMethod) == _kDidPassConnectMethod) {
		if ([self.delegate respondsToSelector:@selector(layerWillDisconnect:withError:)]) {
			[self.delegate layerWillDisconnect:self withError:error];
		}
	}
	
	[self close];
}

#pragma mark Errors

- (NSError *)errorFromCFStreamError:(CFStreamError)err {
	if (err.domain == 0 && err.error == 0) return nil;
	NSString *domain = @"CFStreamError (unlisted domain)", *message = nil;
	
	if (err.domain == kCFStreamErrorDomainPOSIX) {
		domain = NSPOSIXErrorDomain;
	} else if (err.domain == kCFStreamErrorDomainMacOSStatus) {
		domain = NSOSStatusErrorDomain;
	} else if (err.domain == kCFStreamErrorDomainMach) {
		domain = NSMachErrorDomain;
	} else if (err.domain == kCFStreamErrorDomainNetDB) {
		domain = @"kCFStreamErrorDomainNetDB";
		message = [NSString stringWithCString:gai_strerror(err.error) encoding:NSASCIIStringEncoding];
	} else if (err.domain == kCFStreamErrorDomainNetServices) {
		domain = @"kCFStreamErrorDomainNetServices";
	} else if (err.domain == kCFStreamErrorDomainSOCKS) {
		domain = @"kCFStreamErrorDomainSOCKS";
	} else if (err.domain == kCFStreamErrorDomainSystemConfiguration) {
		domain = @"kCFStreamErrorDomainSystemConfiguration";
	} else if (err.domain == kCFStreamErrorDomainSSL) {
		domain = @"kCFStreamErrorDomainSSL";
	}
	
	NSDictionary *info = nil;
	if (message != nil) info = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:domain code:err.error userInfo:info];
}

#pragma mark Diagnostics

- (BOOL)_streamsConnected {
	if (readStream != NULL) {
		CFStreamStatus status = CFReadStreamGetStatus(readStream);
		if (!(status == kCFStreamStatusOpen || status == kCFStreamStatusReading || status == kCFStreamStatusError)) return NO;
	} else return NO;

	if (writeStream != NULL) {
		CFStreamStatus status = CFWriteStreamGetStatus(writeStream);
		if (!(status == kCFStreamStatusOpen || status == kCFStreamStatusWriting || status == kCFStreamStatusError)) return NO;
	} else return NO;

	return YES;
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@"\n"];
	
	if (_socket != NULL) {
		[description appendString:@"\tHost: "];	
#warning complete this
		[description appendString:@"\n"];
	}
	
	if (readStream != NULL || writeStream != NULL) {
		[description appendString:@"\tPeer: "];
		[description appendFormat:@"%@:%@", [(NSOutputStream *)writeStream propertyForKey:(NSString *)kCFStreamPropertySocketRemoteHostName], [(NSOutputStream *)writeStream propertyForKey:(NSString *)kCFStreamPropertySocketRemotePortNumber], nil];	
		[description appendString:@"\n"];
	}
	
	[description appendFormat:@"\t%d pending reads, %d pending writes", [readQueue count], [writeQueue count], nil];
	[description appendString:@"\n"];

	AFPacketRead *readPacket = [self currentReadPacket];
	[description appendFormat:@"\tCurrent Read: %@, ", (readPacket != nil ? @"(null)" : [readPacket description])];
	[description appendFormat:@"\t%@", [readPacket description], nil];
	[description appendString:@"\n"];
	
	AFPacketWrite *writePacket = [self currentWritePacket];
	[description appendFormat:@"\tCurrent Read: %@, ", (writePacket != nil ? @"(null)" : [writePacket description])];
	[description appendFormat:@"\t%@", [writePacket description], nil];
	[description appendString:@"\n"];
	
	{
		static const char *StreamStatusStrings[] = { "not open", "opening", "open", "reading", "writing", "at end", "closed", "has error" };
		
		[description appendFormat:@"\tRead Stream: %p %s, ", readStream, (readStream != NULL ? StreamStatusStrings[CFReadStreamGetStatus(readStream)] : ""), nil];
		
		[description appendFormat:@"\tWrite Stream: %p %s, ", writeStream, (writeStream != NULL ? StreamStatusStrings[CFWriteStreamGetStatus(writeStream)] : ""), nil];	
		if ((self.portFlags & _kCloseSoon) == _kCloseSoon) [description appendString: @"will close pending writes, "];
	}
	[description appendString:@"\n"];
	
	[description appendFormat:@"\tOpen: %@, Closed: %@", ([self isOpen] ? @"YES" : @"NO"), ([self isClosed] ? @"YES" : @"NO"), nil];
	
	return description;
}

#pragma mark Reading

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	if ((self.portFlags & _kForbidStreamReadWrite) == _kForbidStreamReadWrite) return;
	NSParameterAssert(terminator != nil);
	
	AFPacketRead *packet = [[AFPacketRead alloc] initWithTag:tag timeout:duration readAllAvailable:NO terminator:terminator];
	[self _enqueueReadPacket:packet];
	[packet release];
}

#pragma mark Writing

- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration; {
	if ((self.portFlags & _kForbidStreamReadWrite) == _kForbidStreamReadWrite) return;
	if (data == nil || [data length] == 0) return;
	
	AFPacketWrite *packet = [[AFPacketWrite alloc] initWithTag:tag timeout:duration data:data];
	[self _enqueueWritePacket:packet];
	[packet release];
}

#pragma mark Callbacks

static void AFSocketReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFSocketPort *self = [[(AFSocketPort *)pInfo retain] autorelease];
	NSCParameterAssert(stream == self->readStream);
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			[self doStreamOpen];
			break;
		}
		case kCFStreamEventHasBytesAvailable:
		{
			[self _readBytes];
			break;
		}
		case kCFStreamEventErrorOccurred:
		case kCFStreamEventEndEncountered:
		{
#warning these stream events should be non-fatal
			[self disconnectWithError:[self errorFromCFStreamError:CFReadStreamGetError(self->readStream)]];
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

static void AFSocketWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFSocketPort *self = [[(AFSocketPort *)pInfo retain] autorelease];
	NSCParameterAssert(stream == self->writeStream);
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			[self doStreamOpen];
			break;
		}
		case kCFStreamEventCanAcceptBytes:
		{
			[self _sendBytes];
			break;
		}
		case kCFStreamEventErrorOccurred:
		case kCFStreamEventEndEncountered:
		{
#warning these should be non-fatal
			[self disconnectWithError:[self errorFromCFStreamError:CFWriteStreamGetError(self->writeStream)]];
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

@implementation AFSocketPort (Private)

- (void)_emptyQueues {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_dequeueWritePacket) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_dequeueReadPacket) object:nil];
	
	if ([self currentWritePacket] != nil) [self _endCurrentWritePacket];
	[writeQueue removeAllObjects];
	
	if ([self currentReadPacket] != nil) [self _endCurrentReadPacket];
	[readQueue removeAllObjects];
}

- (void)packetDidTimeout:(AFPacket *)packet {
#warning timeout should be non-fatal
	
	if ([packet isEqual:[self currentReadPacket]]) {
		[self _endCurrentReadPacket];
		
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketStreamReadTimeoutError", @"AFSocketStream", [NSBundle mainBundle], @"Read operation timeout", nil), NSLocalizedDescriptionKey,
							  nil];
		
		[self disconnectWithError:[NSError errorWithDomain:AFNetworkingErrorDomain code:AFSocketPortReadTimeoutError userInfo:info]];
	} else if ([packet isEqual:[self currentWritePacket]]) {
		[self _endCurrentWritePacket];
		
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketStreamWriteTimeoutError", @"AFSocketStream", [NSBundle mainBundle], @"Write operation timeout", nil), NSLocalizedDescriptionKey,
							  nil];
		
		[self disconnectWithError:[NSError errorWithDomain:AFNetworkingErrorDomain code:AFSocketPortWriteTimeoutError userInfo:info]];
	}
}

#pragma mark -

- (void)_enqueueReadPacket:(id)packet {
	[readQueue addObject:packet];
	
	[self _dequeueReadPacket];
}

- (void)_dequeueReadPacket {
	if ([self currentReadPacket] != nil) return;
	
	if ([readQueue count] > 0) {
		[self setCurrentReadPacket:[readQueue objectAtIndex:0]];
		[readQueue removeObjectAtIndex:0];
	}
	
	AFPacketRead *packet = [self currentReadPacket];
	if (packet == nil) return;
	
	[packet setDelegate:(id)self];
	[packet startTimeout];
	
	[self _readBytes];
}

- (void)_readBytes {
	AFPacketRead *packet = [self currentReadPacket];
	if (packet == nil || readStream != NULL) return;
	
	NSError *error = nil;
	BOOL packetComplete = [packet read:readStream error:&error];
	
#warning stream errors should be non-fatal
	if (error != nil) [self disconnectWithError:error];
	
	if (packetComplete) {
		[packet.buffer setLength:(packet->bytesDone)];
		
		if ([self.delegate respondsToSelector:@selector(layer:didRead:forTag:)]) {
			[self.delegate layer:self didRead:packet.buffer forTag:packet.tag];
		}
		
		[self _endCurrentReadPacket];
		[self _dequeueReadPacket];
	} else {		
		if ([self.delegate respondsToSelector:@selector(socket:didReadPartialDataOfLength:tag:)]) {
			float percent = 0.0;
			NSUInteger bytesRead = 0.0;
			
			[packet progress:&percent done:&bytesRead total:NULL];
			
			[self.delegate socket:self didReadPartialDataOfLength:bytesRead tag:packet.tag];
		}
	}
}

- (void)_endCurrentReadPacket {
	AFPacketRead *packet = [self currentReadPacket];
	NSAssert(packet != nil, @"cannot complete a nil read packet");
	
	[self setCurrentReadPacket:nil];
}

#pragma mark -

- (void)_enqueueWritePacket:(id)packet {
	[writeQueue addObject:packet];
	
	[self _dequeueWritePacket];
}

- (void)_dequeueWritePacket {
	if ([self currentWritePacket] != nil) return;
	
	if ([writeQueue count] > 0) {
		[self setCurrentWritePacket:[writeQueue objectAtIndex:0]];
		[writeQueue removeObjectAtIndex:0];
	}
	
	
	AFPacketWrite *packet = [self currentWritePacket];
	if (packet == nil) return;
	
	[packet setDelegate:(id)self];
	[packet startTimeout];
	
	[self _sendBytes];
}

- (void)_sendBytes {
	AFPacketWrite *packet = [self currentWritePacket];
	if (packet == nil || writeStream == NULL) return;
	
	NSError *error = nil;
	BOOL packetComplete = [packet write:writeStream error:&error];
	
#warning steam errors should be non-fatal
	if (error != nil) [self disconnectWithError:error];
	
	if (packetComplete) {
		if ([self.delegate respondsToSelector:@selector(layer:didWrite:forTag:)]) {
			[self.delegate layer:self didWrite:packet.buffer forTag:packet.tag];
		}
		
		[self _endCurrentWritePacket];
		[self _dequeueWritePacket];
	}
}

- (void)_endCurrentWritePacket {
	AFPacketWrite *packet = [self currentWritePacket];
	NSAssert(packet != nil, @"cannot complete a nil write packet");
	
	[self setCurrentWritePacket:nil];
	
	
	if ((self.portFlags & _kCloseSoon) != _kCloseSoon) return;
	if (([writeQueue count] != 0) || ([self currentWritePacket] != nil)) return;
	
	[self close];
}

@end

#undef READQUEUE_CAPACITY
#undef WRITEQUEUE_CAPACITY
