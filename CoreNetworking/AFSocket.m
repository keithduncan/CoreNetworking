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

#if 1
/*
 *	These are only used for the connection classes
 */
@property (retain) NSMutableData *partialReadBuffer;
#endif

@end

@interface AFSocket (PacketQueue)
- (void)_emptyQueues;

- (void)_readBytes;
- (void)_dequeueReadPacket;
- (void)_enqueueReadPacket:(id)packet;

- (void)_sendBytes;
- (void)_dequeueWritePacket;
- (void)_enqueueWritePacket:(id)packet;
@end

static void AFSocketStreamSocketCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo);
static void AFSocketStreamReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo);
static void AFSocketStreamWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo);

#pragma mark -

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

- (id)initWithDelegate:(id <AFSocketControlDelegate, AFSocketDataDelegate>)delegate {
	[self init];
	
	self.delegate = delegate;
	
	readQueue = [[NSMutableArray alloc] initWithCapacity:READQUEUE_CAPACITY];
	partialReadBuffer = [[NSMutableData alloc] initWithCapacity:READALL_CHUNKSIZE];
	
	writeQueue = [[NSMutableArray alloc] initWithCapacity:WRITEQUEUE_CAPACITY];
	
	return self;
}

- (void)dealloc {	
	[_currentReadPacket release];
	[readQueue release];
	
	[_currentWritePacket release];
	[writeQueue release];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self.delegate selector:@selector(layerDidDisconnect:) object:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[super dealloc];
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

- (void)enablePreBuffering {
	self.flags = (self.flags | _kEnablePreBuffering);
}

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
	if ((self.flags & _kCloseSoon) != _kCloseSoon && [self.delegate respondsToSelector:@selector(socketShouldRemainOpenPendingWrites:)]) {
		BOOL shouldRemainOpen = [self.delegate socketShouldRemainOpenPendingWrites:self];
		
		if (shouldRemainOpen) {
			self.flags = (self.flags | (_kForbidStreamReadWrite | _kCloseSoon));
			return;
		}
	}
	
	[self _emptyQueues];
	
	self.partialReadBuffer = nil;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(close) object:nil];
	
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
	
	// Note: clear the flags, the stream could be reused.
	// Note: clear the flags before calling the delegate, it could release the stream
	self.flags = 0;
	
	if (notifyDelegate && [self.delegate respondsToSelector:@selector(layerDidClose:)]) {
		[self.delegate layerDidClose:self];
	}
}

- (BOOL)isClosed {
	return (self.flags == 0);
}

#pragma mark Termination

- (void)closeWithError:(NSError *)error {
	self.flags = (self.flags | _kClosingWithError);
	
	if ((self.flags & _kDidPassConnectMethod) == _kDidPassConnectMethod) {
		AsyncReadPacket *packet = [self currentReadPacket];
		
		if (packet != nil) {
			if (packet->bytesDone != 0) {
				[partialReadBuffer replaceBytesInRange:NSMakeRange(0, 0) withBytes:[packet->buffer bytes] length:packet->bytesDone];
			}
		}
		
		if ([self.delegate respondsToSelector:@selector(layerWillDisconnect:error:)]) {
			[self.delegate layerWillDisconnect:self error:error];
		}
	}
	
	[self close];
}

/**
 * In the event of an error, this method may be called during socket:willDisconnectWithError: to read
 * any data that's left on the socket.
**/
- (NSData *)unreadData {
	// Ensure this method will only return data in the event of an error
	if ((self.flags & _kClosingWithError) != _kClosingWithError) return nil;
	if (readStream == NULL) return nil;
	
	CFIndex totalBytesRead = [partialReadBuffer length];
	
	BOOL error = NO;
	while (!error && CFReadStreamHasBytesAvailable(readStream)) {
		[partialReadBuffer increaseLengthBy:READALL_CHUNKSIZE];
		
		// Number of bytes to read is space left in packet buffer.
		CFIndex bytesToRead = [partialReadBuffer length] - totalBytesRead;
		
		// Read data into packet buffer
		UInt8 *packetbuf = (UInt8 *)( [partialReadBuffer mutableBytes] + totalBytesRead );
		CFIndex bytesRead = CFReadStreamRead(readStream, packetbuf, bytesToRead);
		
		// Check results
		if (bytesRead < 0) error = YES;
		else totalBytesRead += bytesRead;
	}
	
	[partialReadBuffer setLength:totalBytesRead];
	
	return partialReadBuffer;
}

#pragma mark Errors

- (NSError *)getErrnoError {
	NSString *errorMsg = [NSString stringWithUTF8String:strerror(errno)];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorMsg forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:userInfo];
}

- (NSError *)getSocketError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketCFSocketError", @"AsyncSocket", [NSBundle mainBundle], @"General CFSocket error", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:AFSocketErrorDomain code:kCFSocketError userInfo:info];
}

- (NSError *)getStreamError {
	CFStreamError err;
	if (readStream != NULL) {
		err = CFReadStreamGetError(readStream);
		if (err.error != 0) return [self errorFromCFStreamError:err];
	}
	
	if (writeStream != NULL) {
		err = CFWriteStreamGetError(writeStream);
		if (err.error != 0) return [self errorFromCFStreamError:err];
	}
	
	return nil;
}

- (NSError *)getAbortError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketCanceledError", @"AsyncSocket", [NSBundle mainBundle], @"Connection canceled", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:AFSocketErrorDomain code:AFSocketAbortError userInfo:info];
}

- (NSError *)getReadMaxedOutError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketReadMaxedOutError", @"AsyncSocket", [NSBundle mainBundle], @"Read operation reached set maximum length", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	return [NSError errorWithDomain:AFSocketErrorDomain code:AFSocketReadMaxedOutError userInfo:info];
}

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

/**
 * Call this method in doBytesAvailable instead of CFReadStreamHasBytesAvailable().
 * This method supports pre-buffering properly.
**/
- (BOOL)_hasBytesAvailable {
	return ([partialReadBuffer length] > 0) || CFReadStreamHasBytesAvailable(readStream);
}

/**
 * Call this method in doBytesAvailable instead of CFReadStreamRead().
 * This method support pre-buffering properly.
**/
- (CFIndex)_readIntoBuffer:(UInt8 *)buffer maxLength:(CFIndex)length {
	if ([partialReadBuffer length] > 0) {
		CFIndex bytesToRead = MIN(length, [partialReadBuffer length]);
		
		memcpy(buffer, [partialReadBuffer bytes], bytesToRead);
		[partialReadBuffer replaceBytesInRange:NSMakeRange(0, bytesToRead) withBytes:NULL length:0];
		
		return bytesToRead;
	}
	
	return CFReadStreamRead(readStream, buffer, length);
}

- (void)_readBytes {
	AsyncReadPacket *packet = [self currentReadPacket];
	if (packet == nil || readStream != NULL) return;
	
	CFIndex totalBytesRead = 0;
	
	BOOL done = NO;
	BOOL socketError = NO, maxoutError = NO;
	
	while (!done && !socketError && !maxoutError && [self _hasBytesAvailable]) {
		BOOL didPreBuffer = NO;
		
		// If reading all available data, make sure there's room in the packet buffer.
		if (packet->readAllAvailableData == YES) {
			// Make sure there is at least READALL_CHUNKSIZE bytes available.
			// We don't want to increase the buffer any more than this or we'll waste space.
			// With prebuffering it's possible to read in a small chunk on the first read.
			unsigned buffInc = (READALL_CHUNKSIZE - ([packet->buffer length] - packet->bytesDone));
			[packet->buffer increaseLengthBy:buffInc];
		}
		
		// If reading until data, we may only want to read a few bytes.
		// Just enough to ensure we don't go past our term or over our max limit.
		// Unless pre-buffering is enabled, in which case we may want to read in a larger chunk.
		if (packet->term != nil) {
			// If we already have data pre-buffered, we obviously don't want to pre-buffer it again.
			// So in this case we'll just read as usual.
			
			if (([partialReadBuffer length] > 0) || ((self.flags & _kEnablePreBuffering) != _kEnablePreBuffering)) {
				unsigned maxToRead = [packet readLengthForTerm];
				
				unsigned bufInc = maxToRead - ([packet->buffer length] - packet->bytesDone);
				[packet->buffer increaseLengthBy:bufInc];
			} else {
				didPreBuffer = YES;
				unsigned maxToRead = [packet prebufferReadLengthForTerm];
				
				unsigned buffInc = maxToRead - ([packet->buffer length] - packet->bytesDone);
				[packet->buffer increaseLengthBy:buffInc];
				
			}
		}
		
		// Number of bytes to read is space left in packet buffer.
		CFIndex bytesToRead = [packet->buffer length] - packet->bytesDone;
		
		// Read data into packet buffer
		UInt8 *subBuffer = (UInt8 *)([packet->buffer mutableBytes] + packet->bytesDone);
		CFIndex bytesRead = [self _readIntoBuffer:subBuffer maxLength:bytesToRead];
		
		// Check results
		if (bytesRead < 0) {
			socketError = YES;
		} else {
			// Update total amound read for the current read
			packet->bytesDone += bytesRead;
			
			// Update total amount read in this method invocation
			totalBytesRead += bytesRead;
		}
		
		// Is packet done?
		if (packet->readAllAvailableData != YES) {
			if (packet->term != nil) {
				if (didPreBuffer) {
					// Search for the terminating sequence within the big chunk we just read.
					CFIndex overflow = [packet searchForTermAfterPreBuffering:bytesRead];
					
					if (overflow > 0) {
						// Copy excess data into partialReadBuffer
						NSMutableData *buffer = packet->buffer;
						const void *overflowBuffer = [buffer bytes] + packet->bytesDone - overflow;
						
						[partialReadBuffer appendBytes:overflowBuffer length:overflow];
						
						// Update the bytesDone variable.
						// Note: The complete[self _currentReadPacket] method will trim the buffer for us.
						packet->bytesDone -= overflow;
					}
					
					done = (overflow >= 0);
				} else {
					// Search for the terminating sequence at the end of the buffer
					int termlen = [packet->term length];
					if(packet->bytesDone >= termlen) {
						const void *buf = [packet->buffer bytes] + (packet->bytesDone - termlen);
						const void *seq = [packet->term bytes];
						done = (memcmp(buf, seq, termlen) == 0);
					}
				}
				
				if (!done && packet->maxLength >= 0 && packet->bytesDone >= packet->maxLength) {
					// There's a set maxLength, and we've reached that maxLength without completing the read
					maxoutError = YES;
				}
			} else {
				// Done when (sized) buffer is full.
				done = ([packet->buffer length] == packet->bytesDone);
			}
		}
		// else readAllAvailable doesn't end until all readable is read.
	}
	
	// Ran out of bytes, so the "read-all-data" type packet is done
	if (packet->readAllAvailableData && packet->bytesDone > 0) done = YES;
	
	if (done) {		
		[packet->buffer setLength:packet->bytesDone];
		
		if ([self.delegate respondsToSelector:@selector(layer:didRead:forTag:)]) {
			[self.delegate layer:self didRead:(packet->buffer) forTag:(packet->tag)];
		}
		
		[self _endCurrentReadPacket];
		
		if (!socketError) {
			[self performSelector:@selector(_dequeueReadPacket) withObject:nil afterDelay:0.0];
			return;
		}
	}
	
	if (packet->bytesDone == 0) return;
	
	if ([self.delegate respondsToSelector:@selector(stream:didReadPartialDataOfLength:tag:)]) {
		[self.delegate socket:self didReadPartialDataOfLength:totalBytesRead tag:(packet->tag)];
	}
	
	if (socketError) {
		CFStreamError err = CFReadStreamGetError(readStream);
		[self closeWithError:[self errorFromCFStreamError:err]];
	} else if (maxoutError) {
		[self closeWithError:[self getReadMaxedOutError]];
	}
}

- (void)_endCurrentReadPacket {
	AsyncReadPacket *packet = [self currentReadPacket];
	NSAssert(packet != nil, @"Trying to end current read when there is no current read.");
	
	[readTimer invalidate];
	readTimer = nil;
}

- (void)_readTimeout:(id)sender {
	if (sender != readTimer) return;
	
	if ([self currentReadPacket] != nil) {
		[self _endCurrentReadPacket];
	}
	
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AFSocketStreamReadTimeoutError", @"AFSocketStream", [NSBundle mainBundle], @"Read operation timeout", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	NSError *timeoutError = [NSError errorWithDomain:AFSocketErrorDomain code:AFSocketReadTimeoutError userInfo:info];
	
	[self closeWithError:timeoutError];
}

#pragma mark Writing

- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration; {
	if ((self.flags & _kForbidStreamReadWrite) == _kForbidStreamReadWrite) return;
	if (data == nil || [data length] == 0) return;
	
	AsyncWritePacket *packet = [[AsyncWritePacket alloc] initWithData:data timeout:duration tag:tag];
	[self _enqueueWritePacket:packet];
	[packet release];
}

- (void)_sendBytes {
	AsyncWritePacket *packet = [self currentWritePacket];
	if (packet == nil || writeStream == NULL) return;

	BOOL done = NO, error = NO;
	while (!done && !error && CFWriteStreamCanAcceptBytes(writeStream)) {
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
		done = ([packet->buffer length] == packet->bytesDone);
	}
	
	if (done) {		
		if ([self.delegate respondsToSelector:@selector(layer:didWrite:forTag:)]) {
			[self.delegate layer:self didWrite:packet->buffer forTag:packet->tag];
		}
		
		[self _endCurrentWritePacket];
		
		if (!error) {
			[self performSelector:@selector(_dequeueWritePacket) withObject:nil afterDelay:0.0];
		}
	}
	
	if (error) {
		CFStreamError error = CFWriteStreamGetError(writeStream);
		[self closeWithError:[self errorFromCFStreamError:error]];
	}
}

- (void)_endCurrentWritePacket {
	AsyncWritePacket *packet = [self currentWritePacket];
	NSAssert(packet != nil, @"cannot complete a nil write packet");
	
	[writeTimer invalidate];
	writeTimer = nil;
	
	if ((self.flags & _kCloseSoon) != _kCloseSoon) return;
	if (([writeQueue count] != 0) || ([self currentWritePacket] != nil)) return;
	
	[self performSelector:@selector(close) withObject:nil afterDelay:0.0];
}

- (void)_writeTimeout:(id)sender {
	if (sender != writeTimer) return; // Old timer. Ignore it.
	
	if ([self currentWritePacket] != nil) {
		[self _endCurrentWritePacket];
	}
	
	NSString *description = NSLocalizedStringWithDefaultValue(@"AFSocketStreamWriteTimeoutError", @"AFSocketStream", [NSBundle mainBundle], @"Write operation timeout", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey];
	NSError *timeoutError = [NSError errorWithDomain:AFSocketErrorDomain code:AFSocketWriteTimeoutError userInfo:info];
	
	[self closeWithError:timeoutError];
}

#pragma mark Callbacks

static void AFSocketStreamSocketCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo) {
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

static void AFSocketStreamReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFSocket *self = [[(AFSocket *)pInfo retain] autorelease];
	NSCParameterAssert(self->readStream != NULL && stream == self->readStream);
	
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
			CFStreamError err = CFReadStreamGetError(self->readStream);
			[self closeWithError:[self errorFromCFStreamError:err]];
			break;
		}
		default:
		{
			NSLog(@"%s, %p received unexpected CFReadStream callback, CFStreamEventType %d.", __PRETTY_FUNCTION__, self, type);
			break;
		}
	}
	
	[pool drain];
}

static void AFSocketStreamWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	AFSocket *self = [[(AFSocket *)pInfo retain] autorelease];
	NSCParameterAssert(self->writeStream != NULL && stream == self->writeStream);
	
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
			CFStreamError err = CFWriteStreamGetError(self->writeStream);
			[self closeWithError:[self errorFromCFStreamError:err]];
			break;
		}
		default:
			NSLog(@"%s, %p, received unexpected CFWriteStream callback, CFStreamEventType %d.", __PRETTY_FUNCTION__, self, type);
			break;
	}
	
	[pool drain];
}

@end

#pragma mark -

@implementation AFSocket (Private)

- (void)_emptyQueues {
	if ([self currentWritePacket] != nil) [self _endCurrentWritePacket];
	[writeQueue removeAllObjects];
	
	if ([self currentReadPacket] != nil) [self _endCurrentReadPacket];
	[readQueue removeAllObjects];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_dequeueWritePacket) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_dequeueReadPacket) object:nil];
}

- (void)_enqueueReadPacket:(id)packet {
	[readQueue addObject:packet];
	
	[self performSelector:@selector(_dequeueReadPacket) withObject:nil afterDelay:0];
}

- (void)_dequeueReadPacket {
	if ([readQueue count] > 0) {
		[self setCurrentReadPacket:[readQueue objectAtIndex:0]];
		[readQueue removeObjectAtIndex:0];
	} else {
		[self setCurrentReadPacket:nil];
		return;
	}
	
	AsyncReadPacket *packet = [self currentReadPacket];
	if (packet == nil) return;
	
	// Start time-out timer.
	if (packet->timeout >= 0.0) {
		readTimer = [NSTimer scheduledTimerWithTimeInterval:(packet->timeout) target:self selector:@selector(doReadTimeout:) userInfo:nil repeats:NO];
	}
	
	[self _readBytes];
}

- (void)_enqueueWritePacket:(id)packet {
	[writeQueue addObject:packet];
	
	[self performSelector:@selector(_dequeueWritePacket) withObject:nil afterDelay:0];
}

- (void)_dequeueWritePacket {
	if ([writeQueue count] > 0) {
		[self setCurrentWritePacket:[writeQueue objectAtIndex:0]];
		[writeQueue removeObjectAtIndex:0];
	} else {
		[self setCurrentWritePacket:nil];
		return;
	}
	
	AsyncWritePacket *packet = [self currentWritePacket];
	if (packet == nil) return;
	
	if (packet->timeout >= 0.0) {
		writeTimer = [NSTimer scheduledTimerWithTimeInterval:(packet->timeout) target:self selector:@selector(_writeTimeout:) userInfo:nil repeats:NO];
	}
	
	[self _sendBytes];
}

@end

#undef READQUEUE_CAPACITY
#undef WRITEQUEUE_CAPACITY
#undef READALL_CHUNKSIZE
#undef WRITE_CHUNKSIZE
