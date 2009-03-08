//
//  AFSocket.m
//
//	Originally based on AsyncSocket http://code.google.com/p/cocoaasyncsocket/
//
//  Created by Keith Duncan
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFSocket.h"

#import <sys/socket.h>

#import <netdb.h>
#import <arpa/inet.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

NSString *const AFSocketErrorDomain = @"AFSocketErrorDomain";

struct _AFSocketType AFSocketTypeTCP = {.socketType = SOCK_STREAM, .protocol = IPPROTO_TCP};
struct _AFSocketType AFSocketTypeUDP = {.socketType = SOCK_DGRAM, .protocol = IPPROTO_UDP};

#define READQUEUE_CAPACITY	5           // Initial capacity
#define WRITEQUEUE_CAPACITY 5           // Initial capacity
#define READALL_CHUNKSIZE	256         // Incremental increase in buffer size
#define WRITE_CHUNKSIZE    (1024 * 4)   // Limit on size of each write pass

enum {
	_kEnablePreBuffering		= 1UL << 0,   // pre-buffering is enabled.
	_kDidCallConnectDelegate	= 1UL << 1,   // connect delegate has been called.
	_kDidPassConnectMethod		= 1UL << 2,   // disconnection results in delegate call.
	_kForbidStreamReadWrite		= 1UL << 3,   // no new reads or writes are allowed.
	_kCloseSoon					= 1UL << 4,   // disconnect as soon as nothing is queued.
	_kClosingWithError			= 1UL << 5,   // the socket is being closed due to an error.
};
typedef NSUInteger AFSocketStreamFlags;

@interface AFSocket ()
@property (assign) NSUInteger flags;
@property (retain) id currentReadPacket, currentWritePacket;
@end

@interface AFSocket (PacketQueue)
- (void)_emptyQueues;

- (void)_enqueueReadPacket:(id)packet;
- (void)_dequeueReadPacket;
- (void)_readTimeout:(id)sender;
- (void)_readBytes;
- (void)_endCurrentReadPacket;

- (void)_enqueueWritePacket:(id)packet;
- (void)_dequeueWritePacket;
- (void)_writeTimeout:(id)sender;
- (void)_sendBytes;
- (void)_endCurrentWritePacket;
@end

static void AFSocketCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo);
static void AFSocketReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo);
static void AFSocketWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo);

#pragma mark -

#error rewrite the internal packet architecture

@interface AsyncReadPacket : NSObject {
 @public
	NSMutableData *buffer;
	
	CFIndex bytesDone;
	NSTimeInterval timeout;
	CFIndex maxLength;
	NSInteger tag;
	NSData *term;
	BOOL readAllAvailableData;
}

- (id)initWithTimeout:(NSTimeInterval)t tag:(NSInteger)i readAllAvailable:(BOOL)a terminator:(NSData *)e maxLength:(CFIndex)m;

- (NSUInteger)readLengthForTerm;
- (NSUInteger)prebufferReadLengthForTerm;

- (CFIndex)searchForTermAfterPreBuffering:(CFIndex)numBytes;

@end

@implementation AsyncReadPacket

- (id)init {
	[super init];
	
	buffer = [[NSMutableData alloc] init];
	
	return self;
}

- (id)initWithTimeout:(NSTimeInterval)t tag:(NSInteger)i readAllAvailable:(BOOL)a terminator:(NSData *)e maxLength:(CFIndex)m {
	[self init];
	
	timeout = t;
	tag = i;
	readAllAvailableData = a;
	term = [e copy];
	maxLength = m;
	
	return self;
}

- (void)dealloc {
	[buffer release];
	[term release];
	
	[super dealloc];
}

/**
 * For read packets with a set terminator, returns the safe length of data that can be read
 * without going over a terminator, or the maxLength.
 * 
 * It is assumed the terminator has not already been read.
**/
- (NSUInteger)readLengthForTerm {
	NSAssert(term != nil, @"Searching for term in data when there is no term.");
	
	// What we're going to do is look for a partial sequence of the terminator at the end of the buffer.
	// If a partial sequence occurs, then we must assume the next bytes to arrive will be the rest of the term,
	// and we can only read that amount.
	// Otherwise, we're safe to read the entire length of the term.
	
	unsigned result = [term length];
	
	// i = index within buffer at which to check data
	// j = length of term to check against
	
	// Note: Beware of implicit casting rules
	// This could give you -1: MAX(0, (0 - [term length] + 1));
	
	CFIndex i = MAX(0, (CFIndex)(bytesDone - [term length] + 1));
	CFIndex j = MIN([term length] - 1, bytesDone);
	
	while(i < bytesDone)
	{
		const void *subBuffer = [buffer bytes] + i;
		
		if(memcmp(subBuffer, [term bytes], j) == 0)
		{
			result = [term length] - j;
			break;
		}
		
		i++;
		j--;
	}
	
	if(maxLength > 0)
		return MIN(result, (maxLength - bytesDone));
	else
		return result;
}

/**
 * Assuming pre-buffering is enabled, returns the amount of data that can be read
 * without going over the maxLength.
**/
- (NSUInteger)prebufferReadLengthForTerm
{
	if (maxLength > 0) return MIN(READALL_CHUNKSIZE, (maxLength - bytesDone));
	else return READALL_CHUNKSIZE;
}

/**
 * For read packets with a set terminator, scans the packet buffer for the term.
 * It is assumed the terminator had not been fully read prior to the new bytes.
 * 
 * If the term is found, the number of excess bytes after the term are returned.
 * If the term is not found, this method will return -1.
 * 
 * Note: A return value of zero means the term was found at the very end.
**/
- (CFIndex)searchForTermAfterPreBuffering:(CFIndex)numBytes
{
	NSAssert(term != nil, @"Searching for term in data when there is no term.");
	
	// We try to start the search such that the first new byte read matches up with the last byte of the term.
	// We continue searching forward after this until the term no longer fits into the buffer.
	
	// Note: Beware of implicit casting rules
	// This could give you -1: MAX(0, 1 - 1 - [term length] + 1);
	
	CFIndex i = MAX(0, (CFIndex)(bytesDone - numBytes - [term length] + 1));
	
	while(i + [term length] <= bytesDone)
	{
		const void *subBuffer = [buffer bytes] + i;
		
		if(memcmp(subBuffer, [term bytes], [term length]) == 0)
		{
			return bytesDone - (i + [term length]);
		}
		
		i++;
	}
	
	return -1;
}

@end

#pragma mark -

@interface AsyncWritePacket : NSObject {
 @public
	NSData *buffer;
	CFIndex bytesDone;
	NSInteger tag;
	NSTimeInterval timeout;
}

- (id)initWithData:(NSData *)d timeout:(NSTimeInterval)t tag:(NSInteger)i;

@end

@implementation AsyncWritePacket

- (id)initWithData:(NSData *)d timeout:(NSTimeInterval)t tag:(NSInteger)i {
	[self init];
	
	buffer = [d retain];
	timeout = t;
	tag = i;
	
	return self;
}

- (void)dealloc {
	[buffer release];
	[super dealloc];
}

@end

#pragma mark -

@implementation AFSocket

@synthesize delegate=_delegate;
@synthesize flags=_flags;

@synthesize hostDelegate=_delegate;

@synthesize currentReadPacket=_currentReadPacket, currentWritePacket=_currentWritePacket;

- (id)initWithDelegate:(id)delegate {
	[self init];
	
	self.delegate = delegate;
	
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

+ (id)hostWithSignature:(const CFSocketSignature *)signature delegate:(id <AFConnectionLayerHostDelegate>)delegate {
	AFSocket *socket = [[self alloc] initWithDelegate:delegate];
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = socket;
	
	socket->_socket = CFSocketCreateWithSocketSignature(kCFAllocatorDefault, signature, kCFSocketAcceptCallBack, AFSocketCallback, &context);
	
	if (socket->_socket == NULL) {
		[socket release];
		return nil;
	}
	
	socket->_socketRunLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket->_socket, 0);
	
	CFRunLoopRef *loop = &socket->_runLoop;
	if ([socket->_delegate respondsToSelector:@selector(socketShouldScheduleWithRunLoop:)]) {
		*loop = [socket->_delegate socketShouldScheduleWithRunLoop:socket];
	} if (*loop == NULL) *loop = CFRunLoopGetMain();
	
	CFRunLoopAddSource(*loop, socket->_socketRunLoopSource, kCFRunLoopDefaultMode);
	
	return socket;
}

+ (id <AFNetworkLayer>)peerWithNetService:(id <AFNetServiceCommon>)netService {
	AFSocket *socket = [[self alloc] init];
	
	return socket;
}

+ (id <AFNetworkLayer>)peerWithSignature:(const AFSocketSignature *)signature {
	AFSocket *socket = [[self alloc] init];
	
	return socket;
}

- (BOOL)canSafelySetDelegate {
	return ([readQueue count] == 0 && [writeQueue count] == 0 && [self currentReadPacket] == nil && [self currentWritePacket] == nil);
}

- (void)currentReadProgress:(float *)value tag:(NSUInteger *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total {
	AsyncReadPacket *packet = [self currentReadPacket];
	if (packet == nil) {
		if (value != NULL) *value = NAN;
		return;
	}
	
	// It's only possible to know the progress of our read if we're reading to a certain length
	// If we're reading to data, we of course have no idea when the data will arrive
	// If we're reading to timeout, then we have no idea when the next chunk of data will arrive.
	BOOL hasTotal = (packet->readAllAvailableData == NO && packet->term == nil);
	
	CFIndex d = packet->bytesDone;
	CFIndex t = hasTotal ? [packet->buffer length] : 0;
	if (tag != NULL)   *tag = packet->tag;
	if (done != NULL)  *done = d;
	if (total != NULL) *total = t;
	
	if (value != NULL) {
		float ratio = (float)d/(float)t;
		*value = (isnan(ratio) ? 1.0 : ratio); // 0 of 0 bytes is 100% done.
	}
}

- (void)currentWriteProgress:(float *)value tag:(NSUInteger *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total {
	AsyncWritePacket *packet = [self currentWritePacket];
	if (packet == nil) {
		if (value != NULL) *value = NAN;
		return;
	}
	
	CFIndex d = packet->bytesDone;
	CFIndex t = [packet->buffer length];
	
	if (tag != NULL)   *tag = packet->tag;
	if (done != NULL)  *done = d;
	if (total != NULL) *total = t;
	if (value != NULL) *value = (float)d/(float)t;
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
	return ((self.flags & _kDidPassConnectMethod) == _kDidPassConnectMethod);
}

- (void)close {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(close) object:nil];
	
	if ((self.flags & _kCloseSoon) != _kCloseSoon) {
		BOOL shouldRemainOpen = NO;
		
		if ([self.delegate respondsToSelector:@selector(socketShouldRemainOpenPendingWrites:)])
			[self.delegate socketShouldRemainOpenPendingWrites:self];
		
		if (shouldRemainOpen) {
			self.flags = (self.flags | (_kForbidStreamReadWrite | _kCloseSoon));
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
	
	BOOL notifyDelegate = ((self.flags & _kDidPassConnectMethod) == _kDidPassConnectMethod);
	
	// Note: clear the flags, self could be reused
	// Note: clear the flags before calling the delegate as it could release self
	self.flags = 0;
	
	if (notifyDelegate && [self.delegate respondsToSelector:@selector(layerDidClose:)]) {
		[self.delegate layerDidClose:self];
	}
}

- (BOOL)isClosed {
	return (self.flags == 0);
}

#pragma mark Termination

- (void)disconnectWithError:(NSError *)error {
	self.flags = (self.flags | _kClosingWithError);
	
	if ((self.flags & _kDidPassConnectMethod) == _kDidPassConnectMethod) {
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

- (BOOL)streamsConnected {
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
	[description appendString:@" "];
	
	if (_socket != NULL) {
		[description appendString:@"Host: "];
		
	}
	
	if (readStream != NULL || writeStream != NULL) {
		[description appendString:@"Peer: "];
		[description appendFormat:@"%@:%@", [(NSOutputStream *)writeStream propertyForKey:(NSString *)kCFStreamPropertySocketRemoteHostName], [(NSOutputStream *)writeStream propertyForKey:(NSString *)kCFStreamPropertySocketRemotePortNumber], nil];	
		[description appendString:@" "];
	}
	
	[description appendFormat:@"%d pending reads, %d pending writes, ", [readQueue count], [writeQueue count], nil];

	AsyncReadPacket *readPacket = [self currentReadPacket];
	[description appendFormat:@"Current Read: %@, ", (readPacket != nil ? @"(null)" : [readPacket description])];
	
#if 0
	else {
		int percentDone = 100;
		if ([readPacket->buffer length] != 0)
			percentDone = (float)readPacket->bytesDone/(float)[readPacket->buffer length] * 100.0;

		[ms appendFormat:@"currently read %u bytes (%d%% done), ", [[self _currentReadPacket]->buffer length], ([self _currentReadPacket]->bytesDone ? percentDone : 0)]];
	}
#endif
	
	AsyncWritePacket *writePacket = [self currentWritePacket];
	[description appendFormat:@"Current Read: %@, ", (writePacket != nil ? @"(null)" : [writePacket description])];
	
#if 0
	else {
		int percentDone = 100;
		if ([writePacket->buffer length] != 0)
			percentDone = (float)writePacket->bytesDone/(float)[writePacket->buffer length] * 100.0;

		[ms appendFormat:@"currently written %u (%d%%), ", [[self _currentWritePacket]->buffer length], ([self _currentWritePacket]->bytesDone ? percentDone : 0)]];
	}
#endif
	
	static const char *StreamStatusStrings[] = { "not open", "opening", "open", "reading", "writing", "at end", "closed", "has error" };
	[description appendFormat:@"Read Stream: %p %s, ", readStream, (readStream != NULL ? StreamStatusStrings[CFReadStreamGetStatus(readStream)] : ""), nil];
	[description appendFormat:@"Write Stream: %p %s, ", writeStream, (writeStream != NULL ? StreamStatusStrings[CFWriteStreamGetStatus(writeStream)] : ""), nil];
	
	if ((self.flags & _kCloseSoon) == _kCloseSoon) [description appendString: @"will close pending writes, "];
	
	[description appendFormat:@"Open: %@, Closed: %@", ([self isOpen] ? @"YES" : @"NO"), ([self isClosed] ? @"YES" : @"NO"), nil];
	
	return description;
}

#pragma mark Reading

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	if ((self.flags & _kForbidStreamReadWrite) == _kForbidStreamReadWrite) return;
	NSParameterAssert(terminator != nil);
	
	NSInteger maxLength = 0;
	NSData *packetTerminator = nil;
	
	if ([terminator isKindOfClass:[NSNumber class]]) {
		maxLength = [terminator integerValue];
		packetTerminator = nil;
	} else if ([terminator isKindOfClass:[NSData class]]) {
		maxLength = -1;
		packetTerminator = terminator;
	}
	
	AsyncReadPacket *packet = [[AsyncReadPacket alloc] initWithTimeout:duration tag:tag readAllAvailable:NO terminator:packetTerminator maxLength:maxLength];
	[self _enqueueReadPacket:packet];
	[packet release];
}

#pragma mark Writing

- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration; {
	if ((self.flags & _kForbidStreamReadWrite) == _kForbidStreamReadWrite) return;
	if (data == nil || [data length] == 0) return;
	
	AsyncWritePacket *packet = [[AsyncWritePacket alloc] initWithData:data timeout:duration tag:tag];
	[self _enqueueWritePacket:packet];
	[packet release];
}

#pragma mark Callbacks

static void AFSocketCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFSocket *self = [[(AFSocket *)pInfo retain] autorelease];
	NSCParameterAssert(socket == self->_socket);
	
	switch (type) {
		case kCFSocketConnectCallBack:
			// The data argument is either NULL or a pointer to an SInt32 error code, if the connect failed.			
			[self doSocketOpen:socket withCFSocketError:(pData != NULL ? kCFSocketError : kCFSocketSuccess)];
			break;
		case kCFSocketAcceptCallBack:
			[self doAcceptWithSocket:*((CFSocketNativeHandle *)pData)];
			break;
		default:
			NSLog(@"%s, socket %p, received unexpected CFSocketCallBackType %d.", __PRETTY_FUNCTION__, self, type);
			break;
	}
	
	[pool drain];
}

static void AFSocketReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFSocket *self = [[(AFSocket *)pInfo retain] autorelease];
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
	
	AFSocket *self = [[(AFSocket *)pInfo retain] autorelease];
	NSCParameterAssert(stream == self->writeStream);
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
			[self doStreamOpen];
			break;
		case kCFStreamEventCanAcceptBytes:
			[self _sendBytes];
			break;
		case kCFStreamEventErrorOccurred:
		case kCFStreamEventEndEncountered:
		{
			[self disconnectWithError:[self errorFromCFStreamError:CFWriteStreamGetError(self->writeStream)]];
			break;
		}
		default:
			NSLog(@"%s, %p, received unexpected CFWriteStream callback, CFStreamEventType %d.", __PRETTY_FUNCTION__, self, type, nil);
			break;
	}
	
	[pool drain];
}

@end

#pragma mark -

@implementation AFSocket (Private)

- (void)_emptyQueues {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_dequeueWritePacket) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_dequeueReadPacket) object:nil];
	
	if ([self currentWritePacket] != nil) [self _endCurrentWritePacket];
	[writeQueue removeAllObjects];
	
	if ([self currentReadPacket] != nil) [self _endCurrentReadPacket];
	[readQueue removeAllObjects];
}

#pragma mark -

- (void)_enqueueReadPacket:(id)packet {
	[readQueue addObject:packet];
	
	[self performSelector:@selector(_dequeueReadPacket) withObject:nil afterDelay:0];
}

- (void)_dequeueReadPacket {
	if ([self currentReadPacket] != nil) return;
	
	if ([readQueue count] > 0) {
		[self setCurrentReadPacket:[readQueue objectAtIndex:0]];
		[readQueue removeObjectAtIndex:0];
	}
	
	AsyncReadPacket *packet = [self currentReadPacket];
	if (packet == nil) return;
	
	
	if (packet->timeout >= 0.0) {
		readTimer = [NSTimer scheduledTimerWithTimeInterval:(packet->timeout) target:self selector:@selector(_readTimeout:) userInfo:nil repeats:NO];
	}
	
	[self _readBytes];
}

- (void)_readTimeout:(id)sender {
	if (sender != readTimer) return;
	
	if ([self currentReadPacket] != nil) {
		[self _endCurrentReadPacket];
	}
	
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  NSLocalizedStringWithDefaultValue(@"AFSocketStreamReadTimeoutError", @"AFSocketStream", [NSBundle mainBundle], @"Read operation timeout", nil), NSLocalizedDescriptionKey,
						  nil];
	
	NSError *timeoutError = [NSError errorWithDomain:AFSocketErrorDomain code:AFSocketReadTimeoutError userInfo:info];
	[self disconnectWithError:timeoutError];
}

- (void)_readBytes {
	AsyncReadPacket *packet = [self currentReadPacket];
	if (packet == nil || readStream != NULL) return;
	
	CFIndex totalBytesRead = 0;
	
	BOOL packetComplete = NO;
	BOOL readStreamError = NO, maxoutError = NO;
	
	while (!packetComplete && !readStreamError && !maxoutError && CFReadStreamHasBytesAvailable(readStream)) {
		// If reading all available data, make sure there's room in the packet buffer.
		if (packet->readAllAvailableData == YES) {
			// Make sure there is at least READALL_CHUNKSIZE bytes available.
			// We don't want to increase the buffer any more than this or we'll waste space.
			// With prebuffering it's possible to read in a small chunk on the first read.
			unsigned bufferIncrement = (READALL_CHUNKSIZE - ([packet->buffer length] - packet->bytesDone));
			[packet->buffer increaseLengthBy:bufferIncrement];
		}
		
		// Number of bytes to read is space left in packet buffer
		CFIndex bytesToRead = ([packet->buffer length] - packet->bytesDone);
		
		// Read data into packet buffer
		UInt8 *buffer = (UInt8 *)([packet->buffer mutableBytes] + packet->bytesDone);
		CFIndex bytesRead = CFReadStreamRead(readStream, buffer, bytesToRead);
		
		if (bytesRead < 0) {
			readStreamError = YES;
		} else {
			packet->bytesDone += bytesRead;
			totalBytesRead += bytesRead;
		}
		
		// Is packet done?
		if (!packet->readAllAvailableData) {
			if (packet->term != nil) {
				int termlen = [packet->term length];
				
				if (packet->bytesDone >= termlen) {
					const void *buf = [packet->buffer bytes] + (packet->bytesDone - termlen);
					const void *seq = [packet->term bytes];
					
					packetComplete = (memcmp(buf, seq, termlen) == 0);
				}
				
				if (!packetComplete && packet->maxLength >= 0 && packet->bytesDone >= packet->maxLength) {
					// There's a set maxLength, and we've reached that maxLength without completing the read
					maxoutError = YES;
				}
			} else {
				// Done when (sized) buffer is full.
				packetComplete = ([packet->buffer length] == packet->bytesDone);
			}
		} // else readAllAvailable doesn't end until all readable is read.
	}
	if (packet->readAllAvailableData && packet->bytesDone > 0) packetComplete = YES;
	
#warning errors should be non-fatal and shouldn't close the stream
	if (readStreamError) {
		[self disconnectWithError:[self errorFromCFStreamError:CFReadStreamGetError(readStream)]];
	}
	
	if (maxoutError) {
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketReadMaxedOutError", @"AFSocket", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Read operation reached set maximum length", nil), NSLocalizedDescriptionKey,
							  nil];
		
		NSError *error = [NSError errorWithDomain:AFSocketErrorDomain code:AFSocketReadMaxedOutError userInfo:info];
		
		[self disconnectWithError:error];
	}
	
	if (packetComplete) {
		[packet->buffer setLength:packet->bytesDone];
		
		if ([self.delegate respondsToSelector:@selector(layer:didRead:forTag:)])
			[self.delegate layer:self didRead:(packet->buffer) forTag:(packet->tag)];
		
		[self _endCurrentReadPacket];
		
		[self performSelector:@selector(_dequeueReadPacket) withObject:nil afterDelay:0.0];
	} else if (packet->bytesDone != 0) {
		if ([self.delegate respondsToSelector:@selector(socket:didReadPartialDataOfLength:tag:)])
			[self.delegate socket:self didReadPartialDataOfLength:totalBytesRead tag:(packet->tag)];
	}
}

- (void)_endCurrentReadPacket {
	AsyncReadPacket *packet = [self currentReadPacket];
	NSAssert(packet != nil, @"cannot complete a nil read packet");
	
	[self setCurrentReadPacket:nil];
	
	[readTimer invalidate];
	readTimer = nil;
}

#pragma mark -

- (void)_enqueueWritePacket:(id)packet {
	[writeQueue addObject:packet];
	
	[self performSelector:@selector(_dequeueWritePacket) withObject:nil afterDelay:0];
}

- (void)_dequeueWritePacket {
	if ([self currentWritePacket] != nil) return;
	
	if ([writeQueue count] > 0) {
		[self setCurrentWritePacket:[writeQueue objectAtIndex:0]];
		[writeQueue removeObjectAtIndex:0];
	}
	
	
	AsyncWritePacket *packet = [self currentWritePacket];
	if (packet == nil) return;
	
	if (packet->timeout >= 0.0) {
		writeTimer = [NSTimer scheduledTimerWithTimeInterval:(packet->timeout) target:self selector:@selector(_writeTimeout:) userInfo:nil repeats:NO];
	}
	
	[self _sendBytes];
}

- (void)_writeTimeout:(id)sender {
	if (sender != writeTimer) return; // Old timer. Ignore it.
	
	if ([self currentWritePacket] != nil) {
		[self _endCurrentWritePacket];
	}
	
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
						  NSLocalizedStringWithDefaultValue(@"AFSocketStreamWriteTimeoutError", @"AFSocketStream", [NSBundle mainBundle], @"Write operation timeout", nil), NSLocalizedDescriptionKey,
						  nil];
	
	NSError *timeoutError = [NSError errorWithDomain:AFSocketErrorDomain code:AFSocketWriteTimeoutError userInfo:info];
	[self disconnectWithError:timeoutError];
}

- (void)_sendBytes {
	AsyncWritePacket *packet = [self currentWritePacket];
	if (packet == nil || writeStream == NULL) return;
	
	BOOL packetComplete = NO, error = NO;
	while (!packetComplete && !error && CFWriteStreamCanAcceptBytes(writeStream)) {
		// Figure out what to write.
		CFIndex bytesRemaining = [packet->buffer length] - packet->bytesDone;
		CFIndex bytesToWrite = (bytesRemaining < WRITE_CHUNKSIZE) ? bytesRemaining : WRITE_CHUNKSIZE;
		UInt8 *writeStart = (UInt8 *)([packet->buffer bytes] + packet->bytesDone);
		
		CFIndex bytesWritten = CFWriteStreamWrite(writeStream, writeStart, bytesToWrite);
		
		if (bytesWritten < 0) {
			bytesWritten = 0;
			error = YES;
		}
		
		packet->bytesDone += bytesWritten;
		packetComplete = ([packet->buffer length] == packet->bytesDone);
	}
	
#warning steam errors should be non-fatal
	if (error) {
		[self disconnectWithError:[self errorFromCFStreamError:CFWriteStreamGetError(writeStream)]];
	}
	
	if (packetComplete) {		
		if ([self.delegate respondsToSelector:@selector(layer:didWrite:forTag:)]) {
			[self.delegate layer:self didWrite:packet->buffer forTag:packet->tag];
		}
		
		[self _endCurrentWritePacket];
		
		[self performSelector:@selector(_dequeueWritePacket) withObject:nil afterDelay:0.0];
	}
}

- (void)_endCurrentWritePacket {
	AsyncWritePacket *packet = [self currentWritePacket];
	NSAssert(packet != nil, @"cannot complete a nil write packet");
	
	[self setCurrentWritePacket:nil];
	
	[writeTimer invalidate];
	writeTimer = nil;
	
	if ((self.flags & _kCloseSoon) != _kCloseSoon) return;
	if (([writeQueue count] != 0) || ([self currentWritePacket] != nil)) return;
	
	[self performSelector:@selector(close) withObject:nil afterDelay:0.0];
}

@end

#undef READQUEUE_CAPACITY
#undef WRITEQUEUE_CAPACITY
#undef READALL_CHUNKSIZE
#undef WRITE_CHUNKSIZE
