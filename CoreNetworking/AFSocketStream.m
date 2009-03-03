//
//  AFSocketStream
//
//	Based on AsyncSocket
//  Renamed to AFSocketStream, API changed, and included in Core Networking by Keith Duncan
//  Original host http://code.google.com/p/cocoaasyncsocket/
//

#import "AFSocketStream.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

#warning this should be instantiated as a local or remote socket with a (transport+internet) layer |struct sockaddr|

#define READQUEUE_CAPACITY	5           // Initial capacity
#define WRITEQUEUE_CAPACITY 5           // Initial capacity
#define READALL_CHUNKSIZE	256         // Incremental increase in buffer size
#define WRITE_CHUNKSIZE    (1024 * 4)   // Limit on size of each write pass

NSString *const AFSocketStreamErrorDomain = @"AFSocketStreamErrorDomain";

enum {
	kEnablePreBuffering		= 1 << 0,   // pre-buffering is enabled.
	kDidCallConnectDelegate = 1 << 1,   // connect delegate has been called.
	kDidPassConnectMethod	= 1 << 2,   // disconnection results in delegate call.
	kForbidStreamReadWrite	= 1 << 3,   // no new reads or writes are allowed.
	kDisconnectSoon			= 1 << 4,   // disconnect as soon as nothing is queued.
	kClosingWithError		= 1 << 5,   // the socket is being closed due to an error.
};
typedef NSUInteger AFSocketStreamFlags;

@interface AFSocketStream ()
@property (assign) NSUInteger flags;
@end

@interface AFSocketStream (Private)
- (id)_currentReadPacket;
- (void)_setCurrentReadPacket:(id)packet;
- (id)_currentWritePacket;
- (void)_setCurrentWritePacket:(id)packet;
- (void)_emptyQueues;
@end

static void AFSocketStreamSocketCallback(CFSocketRef, CFSocketCallBackType, CFDataRef, const void *, void *);
static void AFSocketStreamReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo);
static void AFSocketStreamWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo);

#pragma mark -

/**
 * The AsyncReadPacket encompasses the instructions for a current read.
 * The content of a read packet allows the code to determine if we're:
 * reading to a certain length, reading to a certain separator, or simply reading the first chunk of data.
**/
@interface AsyncReadPacket : NSObject {
 @public
	NSMutableData *buffer;
	
	CFIndex bytesDone;
	NSTimeInterval timeout;
	CFIndex maxLength;
	long tag;
	NSData *term;
	BOOL readAllAvailableData;
}

- (id)initWithTimeout:(NSTimeInterval)t tag:(long)i readAllAvailable:(BOOL)a terminator:(NSData *)e maxLength:(CFIndex)m;

- (unsigned)readLengthForTerm;
- (unsigned)prebufferReadLengthForTerm;

- (CFIndex)searchForTermAfterPreBuffering:(CFIndex)numBytes;

@end

@implementation AsyncReadPacket

- (id)init {
	[super init];
	
	buffer = [[NSMutableData alloc] init];
	
	return self;
}

- (id)initWithTimeout:(NSTimeInterval)t tag:(long)i readAllAvailable:(BOOL)a terminator:(NSData *)e maxLength:(CFIndex)m {
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
- (unsigned)readLengthForTerm {
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
- (unsigned)prebufferReadLengthForTerm
{
	if(maxLength > 0)
		return MIN(READALL_CHUNKSIZE, (maxLength - bytesDone));
	else
		return READALL_CHUNKSIZE;
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
	long tag;
	NSTimeInterval timeout;
}

- (id)initWithData:(NSData *)d timeout:(NSTimeInterval)t tag:(long)i;

@end

@implementation AsyncWritePacket

- (id)initWithData:(NSData *)d timeout:(NSTimeInterval)t tag:(long)i {
	[self init];
	
	buffer = [d retain];
	timeout = t;
	tag = i;
	bytesDone = 0;
	return self;
}

- (void)dealloc {
	[buffer release];
	[super dealloc];
}

@end

#pragma mark -

@implementation AFSocketStream

@synthesize delegate=_delegate;
@synthesize flags=_flags;

@synthesize hostDelegate=_delegate;

- (id)initWithDelegate:(id <AFSocketStreamControlDelegate, AFSocketStreamDataDelegate>)delegate {
	[self init];
	
	self.delegate = delegate;
	
	readQueue = [[NSMutableArray alloc] initWithCapacity:READQUEUE_CAPACITY];
	partialReadBuffer = [[NSMutableData alloc] initWithCapacity:READALL_CHUNKSIZE];
	
	writeQueue = [[NSMutableArray alloc] initWithCapacity:WRITEQUEUE_CAPACITY];
	
	return self;
}

// The socket may been initialized in a connected state and auto-released, so this should close it down cleanly.
- (void)dealloc {
	[self close];
	
	[readQueue release];
	[writeQueue release];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self.delegate selector:@selector(layerDidDisconnect:) object:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[super dealloc];
}

- (BOOL)canSafelySetDelegate {
	return ([readQueue count] == 0 && [writeQueue count] == 0 && [self _currentReadPacket] == nil && [self _currentWritePacket] == nil);
}

- (CFSocketRef)lowerLayer {
	return socket;
}

- (float)progressOfReadReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total {
	AsyncReadPacket *packet = [self _currentReadPacket];
	if (packet == nil) return NAN;
	
	// It's only possible to know the progress of our read if we're reading to a certain length
	// If we're reading to data, we of course have no idea when the data will arrive
	// If we're reading to timeout, then we have no idea when the next chunk of data will arrive.
	BOOL hasTotal = (packet->readAllAvailableData == NO && packet->term == nil);
	
	CFIndex d = packet->bytesDone;
	CFIndex t = hasTotal ? [packet->buffer length] : 0;
	if (tag != NULL)   *tag = packet->tag;
	if (done != NULL)  *done = d;
	if (total != NULL) *total = t;
	float ratio = (float)d/(float)t;
	return isnan(ratio) ? 1.0 : ratio; // 0 of 0 bytes is 100% done.
}

- (float)progressOfWriteReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total {
	AsyncWritePacket *packet = [self _currentWritePacket];
	if (packet == nil) return NAN;
	
	CFIndex d = packet->bytesDone;
	CFIndex t = [packet->buffer length];
	if (tag != NULL)   *tag = packet->tag;
	if (done != NULL)  *done = d;
	if (total != NULL) *total = t;
	return (float)d/(float)t;
}

#pragma mark Configuration

/**
 * See the header file for a full explanation of pre-buffering.
**/
- (void)enablePreBuffering {
	self.flags = (self.flags | kEnablePreBuffering);
}

- (BOOL)startTLS:(NSDictionary *)options {
	options = [[options mutableCopy] autorelease];
	[(id)options setObject:[self connectedHost] forKey:(NSString *)kCFStreamSSLPeerName];
	
	Boolean value = true;
	value &= CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	value &= CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	
	return (value == true ? YES : NO);
}

#pragma mark Connection

/**
 * To accept on a certain address, pass the address to accept on.
 * To accept on any address, pass nil or an empty string.
 * To accept only connections from localhost pass "localhost" or "loopback".
**/
- (BOOL)open:(CFHostRef)host port:(SInt32)port error:(NSError **)errorRef {
	if (self.delegate == nil)
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot open a socket without a delegate", __PRETTY_FUNCTION__, nil];
	
	if (socket != NULL)
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot open a socket which is already open", __PRETTY_FUNCTION__, nil];
	
	CFArrayRef addrs = CFHostGetAddressing(host, NULL);
	if (addrs == NULL || CFArrayGetCount(addrs) == 0) {
		[NSException raise:NSInvalidArgumentException format:@"%s, %p doesn't contain any addresses", __PRETTY_FUNCTION__, host, nil];
	}

	if (addr != nil) {
		struct sockaddr *pSockAddr = (struct sockaddr *)[addr bytes];
		
		CFSocketContext context;
		memset(&context, 0, sizeof(CFSocketContext));
		
		context.info = self;
		
		socket = CFSocketCreate(kCFAllocatorDefault,
								pSockAddr->sa_family,
								SOCK_STREAM,
								0,
								kCFSocketAcceptCallBack,               // Callback flags
								(CFSocketCallBack)AFSocketStreamSocketCallback,  // Callback method
								&context);
		
		if (socket == NULL) {
			if (errorRef != NULL) *errorRef = [self getSocketError];
		}
		
		if (socket == NULL) goto Failed;
	}
	
	int reuseOn = 1;
	setsockopt(CFSocketGetNative(socket), SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));
	
	CFSocketError error = kCFSocketSuccess;
	error = CFSocketSetAddress(socket, (CFDataRef)addr);
	if (error != kCFSocketSuccess) goto Failed;
	
	self.flags = (self.flags | kDidPassConnectMethod);
	return YES;
	
Failed:
	
	if (errorRef != NULL) *errorRef = [self getSocketError];
	
	if (socket != NULL) {
		CFSocketInvalidate(socket);
		CFRelease(socket);
		socket = NULL;
	}
	
	return NO;
}

- (BOOL)connect:(CFHostRef)host error:(NSError **)errPtr {
	if (self.delegate == nil)
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot open a socket without a delegate", __PRETTY_FUNCTION__, nil];
	
	if (socket != NULL)
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot open a socket which is already open", __PRETTY_FUNCTION__, nil];
	
	BOOL pass = YES;
	
	CFStreamCreatePairWithSocketToCFHost(kCFAllocatorDefault, host, <#SInt32 port#>, &readStream, &writeStream);
	
	if (pass) self.flags = (self.flags | kDidPassConnectMethod);
	else [self close];
	
	return pass;
}

#pragma mark -



#pragma mark -

#pragma mark Disconnect Implementation

// Sends error message and disconnects
- (void)closeWithError:(NSError *)err {
	self.flags = (self.flags | kClosingWithError);
	
	if ((self.flags & kDidPassConnectMethod) == kDidPassConnectMethod) {
		// Try to salvage what data we can.
		[self recoverUnreadData];
		
		// Let the delegate know, so it can try to recover if it likes.
		if ([self.delegate respondsToSelector:@selector(layer:willDisconnectWithError:)]) {
			[self.delegate layer:self willDisconnectWithError:err];
		}
	}
	
	[self close];
}

// Prepare partially read data for recovery.
- (void)recoverUnreadData {
	AsyncReadPacket *packet = [self _currentReadPacket];
	if (packet == nil) return;
	if (packet->bytesDone == 0) return;
	
	// We never finished the current read.
	// We need to move its data into the front of the partial read buffer.
		
	[partialReadBuffer replaceBytesInRange:NSMakeRange(0, 0) withBytes:[packet->buffer bytes] length:packet->bytesDone];
	
	[self _emptyQueues];
}

// Disconnects. This is called for both error and clean disconnections.
- (void)close {
	[self _emptyQueues];
	
	[partialReadBuffer release];
	partialReadBuffer = nil;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(disconnect) object:nil];
	
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
	
	
	if (socket != NULL) {
		CFSocketInvalidate(socket);
		CFRelease(socket);
		socket = NULL;
	}
	
	if (socketRunLoopSource != NULL) {
		CFRunLoopRemoveSource(runLoop, socketRunLoopSource, kCFRunLoopDefaultMode);
		CFRelease(socketRunLoopSource);
		socketRunLoopSource = NULL;
	}
		
	runLoop = NULL;
	
#warning is there any other reason that this was cleared after the following delegate message? If not then we can call it synchronously
	BOOL notifyDelegate = ((self.flags & kDidPassConnectMethod) == kDidPassConnectMethod);
	self.flags = 0;
	
	// If the client has passed the connect/accept method, then the connection has at least begun.
	// Notify delegate that it is now ending.
	if (notifyDelegate) {
		// Delay notification to give him freedom to release without returning here and core-dumping.
		if ([(id)self.delegate respondsToSelector:@selector(layerDidDisconnect:)]) {
			[(id)self.delegate performSelector:@selector(layerDidDisconnect:) withObject:self afterDelay:0.0];
		}
	}
}

/**
 * Disconnects immediately. Any pending reads or writes are dropped.
**/
- (void)disconnect {
	[self close];
}

/**
 * Disconnects after all pending writes have completed.
 * After calling this, the read and write methods (including "readDataWithTimeout:tag:") will do nothing.
 * The socket will disconnect even if there are still pending reads.
**/
- (void)disconnectAfterWriting; {
	self.flags = (self.flags | (kForbidStreamReadWrite | kDisconnectSoon));
	[self maybeScheduleDisconnect];
}

/**
 * In the event of an error, this method may be called during socket:willDisconnectWithError: to read
 * any data that's left on the socket.
**/
- (NSData *)unreadData {
	// Ensure this method will only return data in the event of an error
	if ((self.flags & kClosingWithError) != kClosingWithError) return nil;
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

/**
 * Returns a standard error object for the current errno value.
 * Errno is used for low-level BSD socket errors.
**/
- (NSError *)getErrnoError {
	NSString *errorMsg = [NSString stringWithUTF8String:strerror(errno)];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errorMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:userInfo];
}

/**
 * Returns a standard error message for a CFSocket error.
 * Unfortunately, CFSocket offers no feedback on its errors.
**/
- (NSError *)getSocketError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketCFSocketError", @"AsyncSocket", [NSBundle mainBundle], @"General CFSocket error", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AFSocketStreamErrorDomain code:AsyncSocketCFSocketError userInfo:info];
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

/**
 * Returns a standard AsyncSocket abort error.
**/
- (NSError *)getAbortError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketCanceledError", @"AsyncSocket", [NSBundle mainBundle], @"Connection canceled", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AFSocketStreamErrorDomain code:AFSocketStreamCanceledError userInfo:info];
}

- (NSError *)getReadMaxedOutError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketReadMaxedOutError", @"AsyncSocket", [NSBundle mainBundle], @"Read operation reached set maximum length", nil);	
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AFSocketStreamErrorDomain code:AFSocketStreamReadMaxedOutError userInfo:info];
}

/**
 * Returns a standard AsyncSocket read timeout error.
**/
- (NSError *)getReadTimeoutError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketReadTimeoutError", @"AsyncSocket", [NSBundle mainBundle], @"Read operation timed out", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AFSocketStreamErrorDomain code:AFSocketStreamReadTimeoutError userInfo:info];
}

/**
 * Returns a standard AsyncSocket write timeout error.
**/
- (NSError *)getWriteTimeoutError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketWriteTimeoutError", @"AsyncSocket", [NSBundle mainBundle], @"Write operation timed out", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AFSocketStreamErrorDomain code:AFSocketStreamWriteTimeoutError userInfo:info];
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

- (BOOL)isConnected {
	return ([self socketConnected] && [self streamsConnected]);
}

- (BOOL)isDisconnected {
	return !([self isConnected]);
#warning should the socket streams be a linear non-recurring state machine?
}

- (BOOL)streamsConnected {
	CFStreamStatus status;
	
	if (readStream != NULL) {
		status = CFReadStreamGetStatus(readStream);
		if (!(status == kCFStreamStatusOpen || status == kCFStreamStatusReading || status == kCFStreamStatusError)) return NO;
	} else return NO;

	if (writeStream != NULL) {
		status = CFWriteStreamGetStatus(writeStream);
		if (!(status == kCFStreamStatusOpen || status == kCFStreamStatusWriting || status == kCFStreamStatusError)) return NO;
	} else return NO;

	return YES;
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	[description appendString:@" "];
	
	if (socket != NULL) {
		CFDataRef peerAddr = CFSocketCopyPeerAddress(theSocket);

		
		
		[description appendFormat:@"%@ %u", [self addressHost:peeraddr], [self addressPort:peeraddr], nil];
		
		CFRelease(peerAddr);
	} else peerstr = @"nowhere";
	
	if (socket != NULL) {
		if (theSocket) selfaddr  = CFSocketCopyAddress(theSocket);
		if (theSocket6) selfaddr6 = CFSocketCopyAddress(theSocket6);
		
		if (theSocket6 && theSocket) {
			selfstr = [NSString stringWithFormat: @"%@/%@ %u", [self addressHost:selfaddr], [self addressHost:selfaddr6], [self addressPort:selfaddr]];
		} else if (theSocket6) {
			selfstr = [NSString stringWithFormat: @"%@ %u", [self addressHost:selfaddr6], [self addressPort:selfaddr6]];
		} else {
			selfstr = [NSString stringWithFormat: @"%@ %u", [self addressHost:selfaddr], [self addressPort:selfaddr]];
		}
		
		if (selfaddr) CFRelease(selfaddr);
		selfaddr = NULL;
		
		if (selfaddr6) CFRelease(selfaddr6);
		selfaddr6 = NULL;
	} else selfstr = @"nowhere";
	
	
	[description appendFormat:@"has queued %d reads %d writes, ", [readQueue count], [writeQueue count], nil];
	
	static const char *statstr[] = { "not open", "opening", "open", "reading", "writing", "at end", "closed", "has error" };
	CFStreamStatus rs = (readStream != NULL) ? CFReadStreamGetStatus(readStream) : 0;
	CFStreamStatus ws = (writeStream != NULL) ? CFWriteStreamGetStatus(writeStream) : 0;

#if 0
	if ([self _currentReadPacket] == nil) [ms appendString: @"no current read, "];
	else {
		int percentDone;
		if ([[self _currentReadPacket]->buffer length] != 0)
			percentDone = (float)[self _currentReadPacket]->bytesDone / (float)[[self _currentReadPacket]->buffer length] * 100.0;
		else
			percentDone = 100;

		[ms appendString: [NSString stringWithFormat:@"currently read %u bytes (%d%% done), ", [[self _currentReadPacket]->buffer length], ([self _currentReadPacket]->bytesDone ? percentDone : 0)]];
	}

	if ([self _currentWritePacket] == nil) [ms appendString: @"no current write, "];
	else {
		int percentDone;
		if ([[self _currentWritePacket]->buffer length] != 0)
			percentDone = (float)[self _currentWritePacket]->bytesDone /
						  (float)[[self _currentWritePacket]->buffer length] * 100.0;
		else
			percentDone = 100;

		[ms appendString: [NSString stringWithFormat:@"currently written %u (%d%%), ", [[self _currentWritePacket]->buffer length], ([self _currentWritePacket]->bytesDone ? percentDone : 0)]];
	}
	
	[ms appendString: [NSString stringWithFormat:@"read stream %p %s, write stream %p %s", readStream, statstr [rs], writeStream, statstr [ws] ]];
	if ((self.flags & kDisconnectSoon) == kDisconnectSoon) [ms appendString: @", will disconnect soon"];
	if (![self isConnected]) [ms appendString: @", not connected"];

	[ms appendString: @">"];
#endif

	return description;
}

#pragma mark Reading

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration; {
	if ((self.flags & kForbidStreamReadWrite) == kForbidStreamReadWrite) return;
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
 * This method starts a new read, if needed.
 * It is called when a user requests a read,
 * or when a stream opens that may have requested reads sitting in the queue, etc.
**/
- (void)maybeDequeueRead {
	AsyncReadPacket *packet = [self _currentReadPacket];
	if (packet != nil || [readQueue count] == 0 || readStream == NULL) return;
	packet = [self _dequeueReadPacket];

	// Start time-out timer.
	if (packet->timeout >= 0.0) {
		readTimer = [NSTimer scheduledTimerWithTimeInterval:(packet->timeout) target:self selector:@selector(doReadTimeout:) userInfo:nil repeats:NO];
	}
	
	[self doBytesAvailable];
}

/**
 * Call this method in doBytesAvailable instead of CFReadStreamHasBytesAvailable().
 * This method supports pre-buffering properly.
**/
- (BOOL)hasBytesAvailable {
	return ([partialReadBuffer length] > 0) || CFReadStreamHasBytesAvailable(readStream);
}

/**
 * Call this method in doBytesAvailable instead of CFReadStreamRead().
 * This method support pre-buffering properly.
**/
- (CFIndex)readIntoBuffer:(UInt8 *)buffer maxLength:(CFIndex)length {
	if([partialReadBuffer length] > 0) {
		// Determine the maximum amount of data to read
		CFIndex bytesToRead = MIN(length, [partialReadBuffer length]);
		
		// Copy the bytes from the buffer
		memcpy(buffer, [partialReadBuffer bytes], bytesToRead);
		
		// Remove the copied bytes from the buffer
		[partialReadBuffer replaceBytesInRange:NSMakeRange(0, bytesToRead) withBytes:NULL length:0];
		
		return bytesToRead;
	} else {
		return CFReadStreamRead(readStream, buffer, length);
	}
}

/**
 * This method is called when a new read is taken from the read queue or when new data becomes available on the stream.
**/
- (void)doBytesAvailable {
	AsyncReadPacket *packet = [self _currentReadPacket];
	if (packet == nil || readStream != NULL) return;
	
	CFIndex totalBytesRead = 0;
	
	BOOL done = NO;
	BOOL socketError = NO, maxoutError = NO;
	
	while (!done && !socketError && !maxoutError && [self hasBytesAvailable]) {
		BOOL didPreBuffer = NO;
		
		// If reading all available data, make sure there's room in the packet buffer.
		if (packet->readAllAvailableData == YES) {
			// Make sure there is at least READALL_CHUNKSIZE bytes available.
			// We don't want to increase the buffer any more than this or we'll waste space.
			// With prebuffering it's possible to read in a small chunk on the first read.
			
			unsigned buffInc = READALL_CHUNKSIZE - ([packet->buffer length] - packet->bytesDone);
			[packet->buffer increaseLengthBy:buffInc];
		}
		
		// If reading until data, we may only want to read a few bytes.
		// Just enough to ensure we don't go past our term or over our max limit.
		// Unless pre-buffering is enabled, in which case we may want to read in a larger chunk.
		if (packet->term != nil) {
			// If we already have data pre-buffered, we obviously don't want to pre-buffer it again.
			// So in this case we'll just read as usual.
			
			if (([partialReadBuffer length] > 0) || ((self.flags & kEnablePreBuffering) != kEnablePreBuffering))
			{
				unsigned maxToRead = [packet readLengthForTerm];
				
				unsigned bufInc = maxToRead - ([packet->buffer length] - packet->bytesDone);
				[packet->buffer increaseLengthBy:bufInc];
			}
			else
			{
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
		CFIndex bytesRead = [self readIntoBuffer:subBuffer maxLength:bytesToRead];
		
		// Check results
		if(bytesRead < 0)
		{
			socketError = YES;
		}
		else
		{
			// Update total amound read for the current read
			packet->bytesDone += bytesRead;
			
			// Update total amount read in this method invocation
			totalBytesRead += bytesRead;
		}
		
		// Is packet done?
		if(packet->readAllAvailableData != YES)
		{
			if(packet->term != nil)
			{
				if(didPreBuffer)
				{
					// Search for the terminating sequence within the big chunk we just read.
					CFIndex overflow = [packet searchForTermAfterPreBuffering:bytesRead];
					
					if(overflow > 0)
					{
						// Copy excess data into partialReadBuffer
						NSMutableData *buffer = packet->buffer;
						const void *overflowBuffer = [buffer bytes] + packet->bytesDone - overflow;
						
						[partialReadBuffer appendBytes:overflowBuffer length:overflow];
						
						// Update the bytesDone variable.
						// Note: The complete[self _currentReadPacket] method will trim the buffer for us.
						packet->bytesDone -= overflow;
					}
					
					done = (overflow >= 0);
				}
				else
				{
					// Search for the terminating sequence at the end of the buffer
					int termlen = [packet->term length];
					if(packet->bytesDone >= termlen)
					{
						const void *buf = [packet->buffer bytes] + (packet->bytesDone - termlen);
						const void *seq = [packet->term bytes];
						done = (memcmp(buf, seq, termlen) == 0);
					}
				}
				
				if (!done && packet->maxLength >= 0 && packet->bytesDone >= packet->maxLength)
				{
					// There's a set maxLength, and we've reached that maxLength without completing the read
					maxoutError = YES;
				}
			}
			else
			{
				// Done when (sized) buffer is full.
				done = ([packet->buffer length] == packet->bytesDone);
			}
		}
		// else readAllAvailable doesn't end until all readable is read.
	}
	
	if (packet->readAllAvailableData && packet->bytesDone > 0)
		done = YES;	// Ran out of bytes, so the "read-all-data" type packet is done
	
	if (done) {		
		[packet->buffer setLength:packet->bytesDone];
		
		if ([self.delegate respondsToSelector:@selector(layer:didRead:forTag:)]) {
			[self.delegate layer:self didRead:(packet->buffer) forTag:(packet->tag)];
		}
		
		[self endCurrentRead];
		
		if (!socketError) [self performSelector:@selector(maybeDequeueRead) withObject:nil afterDelay:0.0];
		return;
	}
	
	if (packet->bytesDone == 0) return;
	// We're not done with the readToLength or readToData yet, but we have read in some bytes
	if ([self.delegate respondsToSelector:@selector(layer:didReadPartialDataOfLength:tag:)]) {
		[self.delegate layer:self didReadPartialDataOfLength:totalBytesRead tag:(packet->tag)];
	}
	
	if (socketError) {
		CFStreamError err = CFReadStreamGetError(readStream);
		[self closeWithError:[self errorFromCFStreamError:err]];
	} else if (maxoutError) {
		[self closeWithError:[self getReadMaxedOutError]];
	}
}

// Ends current read.
- (void)endCurrentRead {
	AsyncReadPacket *packet = [self _currentReadPacket];
	NSAssert(packet != nil, @"Trying to end current read when there is no current read.");
	
	[readTimer invalidate];
	readTimer = nil;
	
	[self _setCurrentReadPacket:nil];
}

- (void)doReadTimeout:(NSTimer *)timer {
	if (timer != readTimer) return;
	
	if ([self _currentReadPacket] != nil) {
		[self endCurrentRead];
	}
	
	[self closeWithError:[self getReadTimeoutError]];
}

#pragma mark Writing

- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration; {
	if ((self.flags & kForbidStreamReadWrite) == kForbidStreamReadWrite) return;
	if (data == nil || [data length] == 0) return;
	
	AsyncWritePacket *packet = [[AsyncWritePacket alloc] initWithData:data timeout:duration tag:tag];
	[self _enqueueWritePacket:packet];
	[packet release];
}

- (void)maybeDequeueWrite {
	AsyncWritePacket *packet = [self _currentWritePacket];
	if (packet != nil || [writeQueue count] == 0 || writeStream == NULL) return;
	packet = [self _dequeueWritePacket];
	
	// Start time-out timer.
	if (packet->timeout >= 0.0) {
		writeTimer = [NSTimer scheduledTimerWithTimeInterval:packet->timeout target:self selector:@selector(doWriteTimeout:) userInfo:nil repeats:NO];
	}
	
	[self doSendBytes];
}

- (void)doSendBytes {
	AsyncWritePacket *packet = [self _currentWritePacket];
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
		
		[self endCurrentWrite];
		
		if (!error) [self performSelector:@selector(maybeDequeueWrite) withObject:nil afterDelay:0];
	}
	
	if (error) {
		CFStreamError err = CFWriteStreamGetError(writeStream);
		[self closeWithError:[self errorFromCFStreamError:err]];
	}
}

- (void)endCurrentWrite {
	AsyncWritePacket *packet = [self _currentWritePacket];
	NSAssert(packet != nil, @"Trying to complete current write when there is no current write.");
	
	[writeTimer invalidate];
	writeTimer = nil;
	
	[self _setCurrentWritePacket:nil];
	
	[self maybeScheduleDisconnect];
}

// Checks to see if all writes have been completed for disconnectAfterWriting.
- (void)maybeScheduleDisconnect {
	if ((self.flags & kDisconnectSoon) != kDisconnectSoon) return;
	
	if (([writeQueue count] == 0) && ([self _currentWritePacket] == nil)) {
		[self performSelector:@selector(disconnect) withObject:nil afterDelay:0];
	}
}

- (void)doWriteTimeout:(NSTimer *)timer {
	if (timer != writeTimer) return; // Old timer. Ignore it.
	
	if ([self _currentWritePacket] != nil) {
		[self endCurrentWrite];
	}
	
	[self closeWithError:[self getWriteTimeoutError]];
}

#pragma mark Callbacks

static void AFSocketStreamSocketCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	AFSocketStream *self = [[(AFSocketStream *)pInfo retain] autorelease];
	
	NSCAssert((socket == self->socket), @"socket callback for a socket that doesn't belong to this object");
	
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
	AFSocketStream *self = [[(AFSocketStream *)pInfo retain] autorelease];
	
	NSCAssert((self->readStream != NULL), @"readStream is NULL");
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
		{
			[self doStreamOpen];
			break;
		}
		case kCFStreamEventHasBytesAvailable:
		{
			[self doBytesAvailable];
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
			NSLog(@"%s, %p received unexpected CFReadStream callback, CFStreamEventType %d.", __PRETTY_FUNCTION__, self, type);
			break;
	}
	
	[pool drain];
}

static void AFSocketStreamWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	AFSocketStream *self = [[(AFSocketStream *)pInfo retain] autorelease];
	
	NSCAssert((self->writeStream != NULL), @"writeStream is NULL");
	
	switch (type) {
		case kCFStreamEventOpenCompleted:
			[self doStreamOpen];
			break;
		case kCFStreamEventCanAcceptBytes:
			[self doSendBytes];
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

@implementation AFSocketStream (Private)

- (id)_currentReadPacket {
	return _currentReadPacket;
}

- (void)_setCurrentReadPacket:(id)packet {
	[packet retain];
	[_currentReadPacket release];
	_currentReadPacket = packet;
}

- (void)_enqueueReadPacket:(id)packet {
	[readQueue addObject:packet];
	
	[self performSelector:@selector(maybeDequeueRead) withObject:nil afterDelay:0];
}

- (id)_dequeueReadPacket {
	if ([readQueue count] > 0) {
		[self _setCurrentReadPacket:[readQueue objectAtIndex:0]];
		[readQueue removeObjectAtIndex:0];
		return _currentReadPacket;
	}
	
	return nil;
}

- (id)_currentWritePacket {
	return _currentWritePacket;
}

- (void)_setCurrentWritePacket:(id)packet {
	[packet retain];
	[_currentReadPacket release];
	_currentReadPacket = packet;
}

- (void)_enqueueWritePacket:(id)packet {
	[writeQueue addObject:packet];
	
	[self performSelector:@selector(maybeDequeueWrite) withObject:nil afterDelay:0];
}

- (id)_dequeueWritePacket {
	if ([writeQueue count] > 0) {
		[self _setCurrentWritePacket:[writeQueue objectAtIndex:0]];
		[writeQueue removeObjectAtIndex:0];
		return _currentWritePacket;
	}
	
	return nil;
}

- (void)_emptyQueues {
	if ([self _currentReadPacket] != nil) [self endCurrentRead];
	[readQueue removeAllObjects];
	
	if ([self _currentWritePacket] != nil) [self endCurrentWrite];
	[writeQueue removeAllObjects];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(maybeDequeueRead) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(maybeDequeueWrite) object:nil];
}

@end
