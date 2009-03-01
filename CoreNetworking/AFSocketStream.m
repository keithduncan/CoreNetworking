//
//  AsyncSocket.m
//  
//  This class is in the public domain.
//  Originally created by Dustin Voss on Wed Jan 29 2003.
//  Updated and maintained by Deusty Designs and the Mac development community.
//
//  http://code.google.com/p/cocoaasyncsocket/
//

#import "AFSocketStream.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>

#if TARGET_OS_IPHONE
// Note: You may need to add the CFNetwork Framework to your project
#import <CFNetwork/CFNetwork.h>
#endif

#warning theSocket and theSocket6 should be condensed
#warning theSource and theSource6 should be condensed
#warning this should be instantiated as a local or remote socket with a (transport+internet) layer |struct sockaddr|
#warning the connect methods can be condensed to use CFHost instead

#define READQUEUE_CAPACITY	5           // Initial capacity
#define WRITEQUEUE_CAPACITY 5           // Initial capacity
#define READALL_CHUNKSIZE	256         // Incremental increase in buffer size
#define WRITE_CHUNKSIZE    (1024 * 4)   // Limit on size of each write pass

NSString *const AsyncSocketException = @"AsyncSocketException";
NSString *const AsyncSocketErrorDomain = @"AsyncSocketErrorDomain";

// Note: This is a mutex lock used by all instances of AsyncSocket, to protect getaddrinfo.
//	The man page says it is not thread-safe. (As of Mac OS X 10.4.7, and possibly earlier)
static NSString *getaddrinfoLock = @"getaddrinfoLock";

enum {
	kEnablePreBuffering   = 1 << 0,   // If set, pre-buffering is enabled.
	kDidCallConnectDelegate  = 1 << 1,   // If set, connect delegate has been called.
	kDidPassConnectMethod = 1 << 2,   // If set, disconnection results in delegate call.
	kForbidStreamReadWrite    = 1 << 3,   // If set, no new reads or writes are allowed.
	kDisconnectSoon       = 1 << 4,   // If set, disconnect as soon as nothing is queued.
	kClosingWithError     = 1 << 5,   // If set, the socket is being closed due to an error.
};

@interface AFSocketStream (Private)
// Socket Implementation
- (CFSocketRef)createAcceptSocketForAddress:(NSData *)addr error:(NSError **)errPtr;
- (BOOL)createSocketForAddress:(NSData *)remoteAddr error:(NSError **)errPtr;
- (BOOL)attachSocketsToRunLoop:(NSRunLoop *)runLoop error:(NSError **)errPtr;
- (BOOL)configureSocketAndReturnError:(NSError **)errPtr;
- (BOOL)connectSocketToAddress:(NSData *)remoteAddr error:(NSError **)errPtr;
- (void)doAcceptWithSocket:(CFSocketNativeHandle)newSocket;
- (void)doSocketOpen:(CFSocketRef)sock withCFSocketError:(CFSocketError)err;
// Stream Implementation
- (BOOL)createStreamsFromNative:(CFSocketNativeHandle)native error:(NSError **)errPtr;
- (BOOL)createStreamsToHost:(NSString *)hostname onPort:(UInt16)port error:(NSError **)errPtr;
- (BOOL)attachStreamsToRunLoop:(NSRunLoop *)runLoop error:(NSError **)errPtr;
- (BOOL)configureStreamsAndReturnError:(NSError **)errPtr;
- (BOOL)openStreamsAndReturnError:(NSError **)errPtr;
- (void)doStreamOpen;
- (BOOL)setSocketFromStreamsAndReturnError:(NSError **)errPtr;
// Disconnect Implementation
- (void)closeWithError:(NSError *)err;
- (void)recoverUnreadData;
- (void)emptyQueues;
- (void)close;
// Errors
- (NSError *)getErrnoError;
- (NSError *)getAbortError;
- (NSError *)getStreamError;
- (NSError *)getSocketError;
- (NSError *)getReadMaxedOutError;
- (NSError *)getReadTimeoutError;
- (NSError *)getWriteTimeoutError;
- (NSError *)errorFromCFStreamError:(CFStreamError)err;
// Diagnostics
- (BOOL)socketConnected;
- (BOOL)streamsConnected;
- (NSString *)connectedHost:(CFSocketRef)socket;
- (UInt16)connectedPort:(CFSocketRef)socket;
- (NSString *)localHost:(CFSocketRef)socket;
- (UInt16)localPort:(CFSocketRef)socket;
- (NSString *)addressHost:(CFDataRef)cfaddr;
- (UInt16)addressPort:(CFDataRef)cfaddr;
// Reading
- (void)doBytesAvailable;
- (void)completeCurrentRead;
- (void)endCurrentRead;
- (void)scheduleDequeueRead;
- (void)maybeDequeueRead;
- (void)doReadTimeout:(NSTimer *)timer;
// Writing
- (void)doSendBytes;
- (void)completeCurrentWrite;
- (void)endCurrentWrite;
- (void)scheduleDequeueWrite;
- (void)maybeDequeueWrite;
- (void)maybeScheduleDisconnect;
- (void)doWriteTimeout:(NSTimer *)timer;
@end

static void AFSocketStreamsSocketCallback(CFSocketRef, CFSocketCallBackType, CFDataRef, const void *, void *);
static void AFSocketStreamsReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo);
static void AFSocketStreamsWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo);

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
@synthesize context=_context;

@synthesize hostDelegate=_delegate;
@synthesize controlDelegate=_delegate;

- (id)initWithDelegate:(id <AFSocketStreamsControlDelegate, AFSocketStreamsDataDelegate>)delegate {
	[self init];
	
	self.delegate = delegate;
	
	theReadQueue = [[NSMutableArray alloc] initWithCapacity:READQUEUE_CAPACITY];
	partialReadBuffer = [[NSMutableData alloc] initWithCapacity:READALL_CHUNKSIZE];
	
	theWriteQueue = [[NSMutableArray alloc] initWithCapacity:WRITEQUEUE_CAPACITY];
	
	return self;
}

// The socket may been initialized in a connected state and auto-released, so this should close it down cleanly.
- (void)dealloc {
	[self close];
	
	[theReadQueue release];
	[theWriteQueue release];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self.delegate selector:@selector(layerDidDisconnect:) object:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[super dealloc];
}

- (BOOL)canSafelySetDelegate {
	return ([theReadQueue count] == 0 && [theWriteQueue count] == 0 && theCurrentRead == nil && theCurrentWrite == nil);
}

- (CFSocketRef)lowerLayer {
	if (theSocket)
		return theSocket;
	else
		return theSocket6;
}

- (float)progressOfReadReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total {
	if (theCurrentRead == nil) return NAN;
	
	// It's only possible to know the progress of our read if we're reading to a certain length
	// If we're reading to data, we of course have no idea when the data will arrive
	// If we're reading to timeout, then we have no idea when the next chunk of data will arrive.
	BOOL hasTotal = (theCurrentRead->readAllAvailableData == NO && theCurrentRead->term == nil);
	
	CFIndex d = theCurrentRead->bytesDone;
	CFIndex t = hasTotal ? [theCurrentRead->buffer length] : 0;
	if (tag != NULL)   *tag = theCurrentRead->tag;
	if (done != NULL)  *done = d;
	if (total != NULL) *total = t;
	float ratio = (float)d/(float)t;
	return isnan(ratio) ? 1.0 : ratio; // 0 of 0 bytes is 100% done.
}

- (float)progressOfWriteReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total {
	if (theCurrentWrite == nil) return NAN;
	
	CFIndex d = theCurrentWrite->bytesDone;
	CFIndex t = [theCurrentWrite->buffer length];
	if (tag != NULL)   *tag = theCurrentWrite->tag;
	if (done != NULL)  *done = d;
	if (total != NULL) *total = t;
	return (float)d/(float)t;
}

#pragma mark Configuration

/**
 * See the header file for a full explanation of pre-buffering.
**/
- (void)enablePreBuffering {
	flags |= kEnablePreBuffering;
}

- (BOOL)startTLS:(NSDictionary *)options {
	options = [[options mutableCopy] autorelease];
	[(id)options setObject:[self connectedHost] forKey:(NSString *)kCFStreamSSLPeerName];
	
	Boolean value = true;
	value &= CFReadStreamSetProperty(theReadStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	value &= CFWriteStreamSetProperty(theWriteStream, kCFStreamPropertySSLSettings, (CFDictionaryRef)options);
	
	return (value == true ? YES : NO);
}

#pragma mark Connection

/**
 * To accept on a certain address, pass the address to accept on.
 * To accept on any address, pass nil or an empty string.
 * To accept only connections from localhost pass "localhost" or "loopback".
**/
- (BOOL)openPort:(UInt16)port address:(NSString *)hostaddr error:(NSError **)errPtr; {
	if (self.delegate == nil)
		[NSException raise:AsyncSocketException format:@"Attempting to accept without a delegate. Set a delegate first."];
	
	if (theSocket != NULL || theSocket6 != NULL)
		[NSException raise:AsyncSocketException format:@"Attempting to accept while connected or accepting connections. Disconnect first."];
	
	NSData *address4 = nil, *address6 = nil;
	
	if (hostaddr == nil || ([hostaddr length] == 0)) {
		// Accept on ANY address
		struct sockaddr_in nativeAddr;
		nativeAddr.sin_len         = sizeof(struct sockaddr_in);
		nativeAddr.sin_family      = AF_INET;
		nativeAddr.sin_port        = htons(port);
		nativeAddr.sin_addr.s_addr = htonl(INADDR_ANY);
		memset(&(nativeAddr.sin_zero), 0, sizeof(nativeAddr.sin_zero));
		
		struct sockaddr_in6 nativeAddr6;
		nativeAddr6.sin6_len       = sizeof(struct sockaddr_in6);
		nativeAddr6.sin6_family    = AF_INET6;
		nativeAddr6.sin6_port      = htons(port);
		nativeAddr6.sin6_flowinfo  = 0;
		nativeAddr6.sin6_addr      = in6addr_any;
		nativeAddr6.sin6_scope_id  = 0;
		
		// Wrap the native address structures for CFSocketSetAddress.
		address4 = [NSData dataWithBytes:&nativeAddr length:sizeof(nativeAddr)];
		address6 = [NSData dataWithBytes:&nativeAddr6 length:sizeof(nativeAddr6)];
	} else if ([hostaddr isEqualToString:@"localhost"] || [hostaddr isEqualToString:@"loopback"]) {
		struct sockaddr_in nativeAddr;
		nativeAddr.sin_len         = sizeof(struct sockaddr_in);
		nativeAddr.sin_family      = AF_INET;
		nativeAddr.sin_port        = htons(port);
		nativeAddr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
		memset(&(nativeAddr.sin_zero), 0, sizeof(nativeAddr.sin_zero));
	
		struct sockaddr_in6 nativeAddr6;
		nativeAddr6.sin6_len       = sizeof(struct sockaddr_in6);
		nativeAddr6.sin6_family    = AF_INET6;
		nativeAddr6.sin6_port      = htons(port);
		nativeAddr6.sin6_flowinfo  = 0;
		nativeAddr6.sin6_addr      = in6addr_loopback;
		nativeAddr6.sin6_scope_id  = 0;
		
		// Wrap the native address structures for CFSocketSetAddress.
		address4 = [NSData dataWithBytes:&nativeAddr length:sizeof(nativeAddr)];
		address6 = [NSData dataWithBytes:&nativeAddr6 length:sizeof(nativeAddr6)];
	} else {
		NSString *portStr = [NSString stringWithFormat:@"%hu", port];
		
		@synchronized (getaddrinfoLock) {
			struct addrinfo hints, *res, *res0;
			memset(&hints, 0, sizeof(hints));
			
			hints.ai_family   = PF_UNSPEC;
			hints.ai_socktype = SOCK_STREAM;
			hints.ai_protocol = IPPROTO_TCP;
			hints.ai_flags    = AI_PASSIVE;
			
			int error = getaddrinfo([hostaddr UTF8String], [portStr UTF8String], &hints, &res0);
			
			if (error) {
				if (errPtr) {
					NSString *errMsg = [NSString stringWithCString:gai_strerror(error) encoding:NSASCIIStringEncoding];
					NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
					
					*errPtr = [NSError errorWithDomain:@"kCFStreamErrorDomainNetDB" code:error userInfo:info];
				}
			}
			
			for (res = res0; res; res = res->ai_next) {
				if(!address4 && (res->ai_family == AF_INET)) {
					// Found IPv4 address
					// Wrap the native address structures for CFSocketSetAddress.
					address4 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
				} else if(!address6 && (res->ai_family == AF_INET6)) {
					// Found IPv6 address
					// Wrap the native address structures for CFSocketSetAddress.
					address6 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
				}
			}
			
			freeaddrinfo(res0);
		}
		
		if (address4 == nil && address6 == nil) return NO;
	}

	if (address4 != nil) {
		theSocket = [self createAcceptSocketForAddress:address4 error:errPtr];
		if (theSocket == NULL) goto Failed;
	}
	
#if !TARGET_OS_IPHONE
	// Note: The iPhone doesn't currently support IPv6
	if (address6 != nil) {
		theSocket6 = [self createAcceptSocketForAddress:address6 error:errPtr];
		if (theSocket6 == NULL) goto Failed;
	}
#endif
		
	[self attachSocketsToRunLoop:nil error:nil];
	
	// Set the SO_REUSEADDR flags.
	int reuseOn = 1;
	if (theSocket) setsockopt(CFSocketGetNative(theSocket), SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));
	if (theSocket6)	setsockopt(CFSocketGetNative(theSocket6), SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));

	// Set the local bindings which causes the sockets to start listening.

	CFSocketError err;
	
	if (theSocket != NULL) {
		err = CFSocketSetAddress (theSocket, (CFDataRef)address4);
		if (err != kCFSocketSuccess) goto Failed;
	}
	
	if (theSocket6 != NULL) {
		if (port == 0 && theSocket != NULL) {
			UInt16 chosenPort = [self localPort:theSocket];			
			struct sockaddr_in6 *pSockAddr6 = (struct sockaddr_in6 *)[address6 bytes];
			pSockAddr6->sin6_port = htons(chosenPort);
		}
		
		err = CFSocketSetAddress(theSocket6, (CFDataRef)address6);
		if (err != kCFSocketSuccess) goto Failed;
	}

	flags |= kDidPassConnectMethod;
	return YES;
	
Failed:
	
	if (errPtr != NULL) *errPtr = [self getSocketError];
	
	if (theSocket != NULL) {
		CFSocketInvalidate(theSocket);
		CFRelease(theSocket);
		theSocket = NULL;
	}
	
	if (theSocket6 != NULL) {
		CFSocketInvalidate(theSocket6);
		CFRelease(theSocket6);
		theSocket6 = NULL;
	}
	
	return NO;
}

/**
 * This method creates an initial CFReadStream and CFWriteStream to the given host on the given port.
 * The connection is then opened, and the corresponding CFSocket will be extracted after the connection succeeds.
 *
 * Thus the delegate will have access to the CFReadStream and CFWriteStream prior to connection,
 * specifically in the socketWillConnect: method.
**/

- (BOOL)connectToHost:(NSString *)hostname onPort:(UInt16)port error:(NSError **)errPtr {
	if (self.delegate == nil) {
		NSString *message = @"Attempting to connect without a delegate. Set a delegate first.";
		[NSException raise:AsyncSocketException format:message];
	}

	if (theSocket != NULL || theSocket6 != NULL) {
		NSString *message = @"Attempting to connect while connected or accepting connections. Disconnect first.";
		[NSException raise:AsyncSocketException format:message];
	}
	
	BOOL pass = YES;
	if (pass) pass &= [self createStreamsToHost:hostname onPort:port error:errPtr];
	if (pass) pass &= [self attachStreamsToRunLoop:nil error:errPtr];
	if (pass) pass &= [self configureStreamsAndReturnError:errPtr];
	if (pass) pass &= [self openStreamsAndReturnError:errPtr];  
	
#warning the -attach... -configure... and -open... methods can be collapsed
	
	if (pass) flags |= kDidPassConnectMethod;
	else [self close];
	
	return pass;
}

- (BOOL)connectToAddress:(NSData *)remoteAddr error:(NSError **)errPtr {
	if (self.delegate == nil) {
		NSString *message = @"Attempting to connect without a delegate. Set a delegate first.";
		[NSException raise:AsyncSocketException format:message];
	}
	
	if (theSocket != NULL || theSocket6 != NULL) {
		NSString *message = @"Attempting to connect while connected or accepting connections. Disconnect first.";
		[NSException raise:AsyncSocketException format:message];
	}
	
	BOOL pass = YES;
	if (pass) pass &= [self createSocketForAddress:remoteAddr error:errPtr];
	if (pass) pass &= [self attachSocketsToRunLoop:nil error:errPtr];
	if (pass) pass &= [self configureSocketAndReturnError:errPtr];
	if (pass) pass &= [self connectSocketToAddress:remoteAddr error:errPtr];
	
	if (pass) flags |= kDidPassConnectMethod;
	else [self close];
	
	return pass;
}

#pragma mark Socket Implementation

/**
 * Creates the accept sockets.
 * Returns true if either IPv4 or IPv6 is created.
 * If either is missing, an error is returned (even though the method may return true).
**/

- (CFSocketRef)createAcceptSocketForAddress:(NSData *)addr error:(NSError **)errPtr
{
	struct sockaddr *pSockAddr = (struct sockaddr *)[addr bytes];
	int addressFamily = pSockAddr->sa_family;
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	
	context.info = self;
	
	CFSocketRef socket = CFSocketCreate(kCFAllocatorDefault,
										addressFamily,
										SOCK_STREAM,
										0,
										kCFSocketAcceptCallBack,               // Callback flags
										(CFSocketCallBack)AFSocketStreamsSocketCallback,  // Callback method
										&context);

	if (socket == NULL) {
		if (errPtr != NULL) *errPtr = [self getSocketError];
	}
	
	return socket;
}

- (BOOL)createSocketForAddress:(NSData *)remoteAddr error:(NSError **)errPtr {
	struct sockaddr *pSockAddr = (struct sockaddr *)[remoteAddr bytes];
	int addressFamily = pSockAddr->sa_family;
	
	CFSocketRef *socketRef = NULL;
	if (addressFamily == AF_INET) {
		socketRef = &theSocket;
	} else if (addressFamily == AF_INET6) {
		socketRef = &theSocket6;
	}
	
	if (socketRef == NULL) {
		if (errPtr) *errPtr = [self getSocketError];
		return NO;
	} else {
		CFSocketContext context;
		memset(&context, 0, sizeof(CFSocketContext));
		
		context.info = self;
		
		*socketRef = CFSocketCreate(NULL,									// Default allocator
									addressFamily,							// Protocol Family
									SOCK_STREAM,							// Socket Type
									0,										// Protocol
									kCFSocketConnectCallBack,				// Callback flags
									(CFSocketCallBack)AFSocketStreamsSocketCallback,	// Callback method
									&context);							// Socket Context
		
		if (*socketRef == NULL) {
			if (errPtr) *errPtr = [self getSocketError];
			return NO;
		}
	}
	
	return YES;
}

/**
 * Adds the CFSocket's to the run-loop so that callbacks will work properly.
**/
- (BOOL)attachSocketsToRunLoop:(NSRunLoop *)runLoop error:(NSError **)errPtr
{
	// Get the CFRunLoop to which the socket should be attached.
	theRunLoop = (runLoop == nil) ? CFRunLoopGetCurrent() : [runLoop getCFRunLoop];
	
	if (theSocket != nil) {
		theSource  = CFSocketCreateRunLoopSource (kCFAllocatorDefault, theSocket, 0);
		CFRunLoopAddSource (theRunLoop, theSource, kCFRunLoopDefaultMode);
	}
	
	if (theSocket6 != nil) {
		theSource6 = CFSocketCreateRunLoopSource (kCFAllocatorDefault, theSocket6, 0);
		CFRunLoopAddSource (theRunLoop, theSource6, kCFRunLoopDefaultMode);
	}
	
	return YES;
}

/**
 * Allows the delegate method to configure the CFSocket or CFNativeSocket as desired before we connect.
 * Note that the CFReadStream and CFWriteStream will not be available until after the connection is opened.
**/
- (BOOL)configureSocketAndReturnError:(NSError **)errPtr {
	if ([self.delegate respondsToSelector:@selector(layerWillConnect:)]) {
		if ([self.delegate layerWillConnect:self] == NO) {
			if (errPtr) *errPtr = [self getAbortError];
			return NO;
		}
	}
	
	return YES;
}

- (BOOL)connectSocketToAddress:(NSData *)remoteAddr error:(NSError **)errPtr {
	if (theSocket) {
		CFSocketError err = CFSocketConnectToAddress(theSocket, (CFDataRef)remoteAddr, -1);
		if (err != kCFSocketSuccess) {
			if (errPtr) *errPtr = [self getSocketError];
			return NO;
		}
	} else if (theSocket6) {
		CFSocketError err = CFSocketConnectToAddress(theSocket6, (CFDataRef)remoteAddr, -1);
		if (err != kCFSocketSuccess) {
			if (errPtr) *errPtr = [self getSocketError];
			return NO;
		}
	}
	
	return YES;
}

- (void)doAcceptWithSocket:(CFSocketNativeHandle)newNative {
	// Note: We use [self class] to support subclassing AsyncSocket.
	AFSocketStream *newSocket = [[[[self class] alloc] initWithDelegate:self.delegate] autorelease];
	
	if ([self.delegate respondsToSelector:@selector(layer:didAcceptConnection:)])
		[self.delegate layer:self didAcceptConnection:newSocket];
	
	if (newSocket != nil) {
		NSRunLoop *runLoop = nil;
		if ([self.delegate respondsToSelector:@selector(layer:runLoopForNewLayer:)])
			runLoop = [self.delegate layer:self runLoopForNewLayer:newSocket];
		
		BOOL pass = YES;
		if (pass && ![newSocket createStreamsFromNative:newNative error:nil]) pass = NO;
		if (pass && ![newSocket attachStreamsToRunLoop:runLoop error:nil])    pass = NO;
		if (pass && ![newSocket configureStreamsAndReturnError:nil])          pass = NO;
		if (pass && ![newSocket openStreamsAndReturnError:nil])               pass = NO;
		
		if (pass) {
			newSocket->flags |= kDidPassConnectMethod;
		} else {
			// No NSError, but errors will still get logged from the above functions.
			[newSocket close];
		}
	}
}

/**
 * Description forthcoming...
**/
- (void)doSocketOpen:(CFSocketRef)sock withCFSocketError:(CFSocketError)socketError; {
	NSParameterAssert((sock == theSocket) || (sock == theSocket6));
	
	if (socketError == kCFSocketTimeout || socketError == kCFSocketError) {
		[self closeWithError:[self getSocketError]];
		return;
	}
	
	// Get the underlying native (BSD) socket
	CFSocketNativeHandle nativeSocket = CFSocketGetNative(sock);
	// Setup the socket so that invalidating the socket will not close the native socket
	CFSocketSetSocketFlags(sock, 0);
	
	// Invalidate and release the CFSocket - All we need from here on out is the nativeSocket
	// Note: If we don't invalidate the socket (leaving the native socket open)
	// then theReadStream and theWriteStream won't function properly.
	// Specifically, their callbacks won't work, with the exception of kCFStreamEventOpenCompleted.
	// I'm not entirely sure why this is, but I'm guessing that events on the socket fire to the CFSocket we created,
	// as opposed to the CFReadStream/CFWriteStream.
	
	CFSocketInvalidate(sock);
	CFRelease(sock);
	
	theSocket = NULL;
	theSocket6 = NULL;
	
	BOOL pass = YES; NSError *err = nil;
	if (pass && ![self createStreamsFromNative:nativeSocket error:&err]) pass = NO;
	if (pass && ![self attachStreamsToRunLoop:nil error:&err])           pass = NO;
	if (pass && ![self openStreamsAndReturnError:&err])                  pass = NO;
	
	if (!pass) [self closeWithError:err];
}

#pragma mark Stream Implementation

/**
 * Creates the CFReadStream and CFWriteStream from the given native socket.
 * The CFSocket may be extracted from either stream after the streams have been opened.
 * 
 * Note: The given native socket must already be connected!
**/
- (BOOL)createStreamsFromNative:(CFSocketNativeHandle)native error:(NSError **)errPtr; {
	// Create the socket & streams.
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, native, &theReadStream, &theWriteStream);
	if (theReadStream == NULL || theWriteStream == NULL) {
		NSError *err = [self getStreamError];
		NSLog (@"AsyncSocket %p couldn't create streams from accepted socket: %@", self, err);
		if (errPtr) *errPtr = err;
		return NO;
	}
	
	// Ensure the CF & BSD socket is closed when the streams are closed.
	CFReadStreamSetProperty(theReadStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(theWriteStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	
#warning this shouldn't be set here, it should be done in the same method (above) in the native socket extraction method that invalidates the CFSocket
	
	return YES;
}

/**
 * Creates the CFReadStream and CFWriteStream from the given hostname and port number.
 * The CFSocket may be extracted from either stream after the streams have been opened.
**/
- (BOOL)createStreamsToHost:(NSString *)hostname onPort:(UInt16)port error:(NSError **)errPtr {
	CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (CFStringRef)hostname, port, &theReadStream, &theWriteStream);
	
	if (theReadStream == NULL || theWriteStream == NULL) {
		if (errPtr) *errPtr = [self getStreamError];
		return NO;
	}
	
	// Ensure the CF & BSD socket is closed when the streams are closed.
	CFReadStreamSetProperty(theReadStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(theWriteStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	
#warning this shouldn't be set here, it should be done in the same method (above) in the native socket extraction method that invalidates the CFSocket
	
	return YES;
}

- (BOOL)attachStreamsToRunLoop:(NSRunLoop *)runLoop error:(NSError **)errPtr {
	// Get the CFRunLoop to which the socket should be attached.
	theRunLoop = (runLoop == nil) ? CFRunLoopGetCurrent() : [runLoop getCFRunLoop];

	CFStreamClientContext streamContext;
	memset(&streamContext, 0, sizeof(CFStreamClientContext));
	
	streamContext.info = self;
	
	// Make read stream non-blocking.
	if (!CFReadStreamSetClient(theReadStream, (kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted), (CFReadStreamClientCallBack)AFSocketStreamsReadStreamCallback, &streamContext)) {
		NSError *err = [self getStreamError];
		
		NSLog (@"AsyncSocket %p couldn't attach read stream to run-loop,", self);
		NSLog (@"Error: %@", err);
		
		if (errPtr) *errPtr = err;
		return NO;
	}
	
	CFReadStreamScheduleWithRunLoop(theReadStream, theRunLoop, kCFRunLoopDefaultMode);

	// Make write stream non-blocking.
	if (!CFWriteStreamSetClient(theWriteStream, (kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted), (CFWriteStreamClientCallBack)AFSocketStreamsWriteStreamCallback, &streamContext)) {
		NSError *err = [self getStreamError];
		
		NSLog (@"AsyncSocket %p couldn't attach write stream to run-loop,", self);
		NSLog (@"Error: %@", err);
		
		if (errPtr) *errPtr = err;
		return NO;
		
	}
	
	CFWriteStreamScheduleWithRunLoop(theWriteStream, theRunLoop, kCFRunLoopDefaultMode);
	
	return YES;
}

/**
 * Allows the delegate method to configure the CFReadStream and/or CFWriteStream as desired before we connect.
 * Note that the CFSocket and CFNativeSocket will not be available until after the connection is opened.
**/
- (BOOL)configureStreamsAndReturnError:(NSError **)errPtr {
	// Call the delegate method for further configuration.
	if ([self.delegate respondsToSelector:@selector(layerWillConnect:)]) {
		if ([self.delegate layerWillConnect:self] == NO) {
			if (errPtr) *errPtr = [self getAbortError];
			return NO;
		}
	}
	
	return YES;
}

- (BOOL)openStreamsAndReturnError:(NSError **)errPtr
{
	BOOL pass = YES;
	
	if(pass && !CFReadStreamOpen (theReadStream))
	{
		NSLog (@"AsyncSocket %p couldn't open read stream,", self);
		pass = NO;
	}
	
	if(pass && !CFWriteStreamOpen (theWriteStream))
	{
		NSLog (@"AsyncSocket %p couldn't open write stream,", self);
		pass = NO;
	}
	
	if(!pass)
	{
		if (errPtr) *errPtr = [self getStreamError];
	}
	
	return pass;
}

/**
 * Called when read or write streams open.
 * When the socket is connected and both streams are open, consider the AsyncSocket instance to be ready.
**/
- (void)doStreamOpen
{
	NSError *err = nil;
	if ([self streamsConnected] && !(flags & kDidCallConnectDelegate))
	{
		// Get the socket.
		if (![self setSocketFromStreamsAndReturnError: &err]) {
			NSLog (@"AsyncSocket %p couldn't get socket from streams, %@. Disconnecting.", self, err);
			[self closeWithError:err];
			return;
		}
		
		if ([self.delegate respondsToSelector:@selector(layer:didConnectToHost:)]) {
			CFDataRef addrData = CFSocketCopyPeerAddress([self lowerLayer]);
			[self.delegate layer:self didConnectToHost:(const struct sockaddr *)CFDataGetBytePtr(addrData)];
			CFRelease(addrData);
		} else if ([self.delegate respondsToSelector:@selector(layerDidConnect:)]) {
			[self.delegate layerDidConnect:self];
		}
		
		// Call the delegate.
		flags |= kDidCallConnectDelegate;
		
		// Immediately deal with any already-queued requests.
		[self maybeDequeueRead];
		[self maybeDequeueWrite];
	}
}

- (BOOL)setSocketFromStreamsAndReturnError:(NSError **)errPtr
{
	// Get the CFSocketNativeHandle from theReadStream
	CFSocketNativeHandle native;
	CFDataRef nativeProp = CFReadStreamCopyProperty(theReadStream, kCFStreamPropertySocketNativeHandle);
	if(nativeProp == NULL)
	{
		if (errPtr) *errPtr = [self getStreamError];
		return NO;
	}
	
	CFDataGetBytes(nativeProp, CFRangeMake(0, CFDataGetLength(nativeProp)), (UInt8 *)&native);
	CFRelease(nativeProp);
	
	CFSocketRef socket = CFSocketCreateWithNative(kCFAllocatorDefault, native, 0, NULL, NULL);
	if(socket == NULL)
	{
		if (errPtr) *errPtr = [self getSocketError];
		return NO;
	}
	
	// Determine whether the connection was IPv4 or IPv6
	CFDataRef peeraddr = CFSocketCopyPeerAddress(socket);
	struct sockaddr *sa = (struct sockaddr *)CFDataGetBytePtr(peeraddr);
	
	if (sa->sa_family == AF_INET) {
		theSocket = socket;
	} else {
		theSocket6 = socket;
	}
	
	CFRelease(peeraddr);

	return YES;
}

#pragma mark Disconnect Implementation

// Sends error message and disconnects
- (void)closeWithError:(NSError *)err {
	flags |= kClosingWithError;
	
	if ((flags & kDidPassConnectMethod) == kDidPassConnectMethod) {
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
	if((theCurrentRead != nil) && (theCurrentRead->bytesDone > 0)) {
		// We never finished the current read.
		// We need to move its data into the front of the partial read buffer.
		
		[partialReadBuffer replaceBytesInRange:NSMakeRange(0, 0) withBytes:[theCurrentRead->buffer bytes] length:theCurrentRead->bytesDone];
	}
	
	[self emptyQueues];
}

- (void)emptyQueues {
	if (theCurrentRead != nil)	[self endCurrentRead];
	if (theCurrentWrite != nil)	[self endCurrentWrite];
	
	[theReadQueue removeAllObjects];
	[theWriteQueue removeAllObjects];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(maybeDequeueRead) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(maybeDequeueWrite) object:nil];
}

// Disconnects. This is called for both error and clean disconnections.
- (void)close {
	[self emptyQueues];
	
	[partialReadBuffer release];
	partialReadBuffer = nil;
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(disconnect) object:nil];
	
	// Close streams.
	if (theReadStream != NULL) {
		CFReadStreamSetClient(theReadStream, kCFStreamEventNone, NULL, NULL);
		CFReadStreamClose(theReadStream);
		CFRelease(theReadStream);
		
		theReadStream = NULL;
	}
	
	if (theWriteStream != NULL) {
		CFWriteStreamSetClient(theWriteStream, kCFStreamEventNone, NULL, NULL);
		CFWriteStreamClose(theWriteStream);
		CFRelease(theWriteStream);
		
		theWriteStream = NULL;
	}
	
	// Close sockets.
	if (theSocket != NULL) {
		CFSocketInvalidate(theSocket);
		CFRelease(theSocket);
		theSocket = NULL;
	}
	
	if (theSocket6 != NULL) {
		CFSocketInvalidate(theSocket6);
		CFRelease(theSocket6);
		theSocket6 = NULL;
	}
	
	
	if (theSource != NULL) {
		CFRunLoopRemoveSource(theRunLoop, theSource, kCFRunLoopDefaultMode);
		CFRelease (theSource);
		theSource = NULL;
	}
	
	if (theSource6 != NULL) {
		CFRunLoopRemoveSource(theRunLoop, theSource6, kCFRunLoopDefaultMode);
		CFRelease(theSource6);
		theSource6 = NULL;
	}
	
	theRunLoop = NULL;
	
#warning is there any other reason that this was cleared after the following delegate message? If not then we can call it synchronously
	BOOL notifyDelegate = ((flags & kDidPassConnectMethod) == kDidPassConnectMethod);
	flags = 0;
	
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
	flags |= (kForbidStreamReadWrite | kDisconnectSoon);
	[self maybeScheduleDisconnect];
}

/**
 * In the event of an error, this method may be called during socket:willDisconnectWithError: to read
 * any data that's left on the socket.
**/
- (NSData *)unreadData {
	// Ensure this method will only return data in the event of an error
	if ((flags & kClosingWithError) != kClosingWithError) return nil;
	if (theReadStream == NULL) return nil;
	
	CFIndex totalBytesRead = [partialReadBuffer length];
	
	BOOL error = NO;
	while (!error && CFReadStreamHasBytesAvailable(theReadStream)) {
		[partialReadBuffer increaseLengthBy:READALL_CHUNKSIZE];
		
		// Number of bytes to read is space left in packet buffer.
		CFIndex bytesToRead = [partialReadBuffer length] - totalBytesRead;
		
		// Read data into packet buffer
		UInt8 *packetbuf = (UInt8 *)( [partialReadBuffer mutableBytes] + totalBytesRead );
		CFIndex bytesRead = CFReadStreamRead(theReadStream, packetbuf, bytesToRead);
		
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
	
	return [NSError errorWithDomain:AsyncSocketErrorDomain code:AsyncSocketCFSocketError userInfo:info];
}

- (NSError *) getStreamError {
	CFStreamError err;
	if (theReadStream != NULL) {
		err = CFReadStreamGetError(theReadStream);
		if (err.error != 0) return [self errorFromCFStreamError:err];
	}
	
	if (theWriteStream != NULL) {
		err = CFWriteStreamGetError(theWriteStream);
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
	
	return [NSError errorWithDomain:AsyncSocketErrorDomain code:AsyncSocketCanceledError userInfo:info];
}

- (NSError *)getReadMaxedOutError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketReadMaxedOutError", @"AsyncSocket", [NSBundle mainBundle], @"Read operation reached set maximum length", nil);	
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncSocketErrorDomain code:AsyncSocketReadMaxedOutError userInfo:info];
}

/**
 * Returns a standard AsyncSocket read timeout error.
**/
- (NSError *)getReadTimeoutError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketReadTimeoutError", @"AsyncSocket", [NSBundle mainBundle], @"Read operation timed out", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncSocketErrorDomain code:AsyncSocketReadTimeoutError userInfo:info];
}

/**
 * Returns a standard AsyncSocket write timeout error.
**/
- (NSError *)getWriteTimeoutError {
	NSString *errMsg = NSLocalizedStringWithDefaultValue(@"AsyncSocketWriteTimeoutError", @"AsyncSocket", [NSBundle mainBundle], @"Write operation timed out", nil);
	NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
	
	return [NSError errorWithDomain:AsyncSocketErrorDomain code:AsyncSocketWriteTimeoutError userInfo:info];
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

- (NSString *)connectedHost {
	if (theSocket)
		return [self connectedHost:theSocket];
	else
		return [self connectedHost:theSocket6];
}

- (UInt16)connectedPort {
	if (theSocket)
		return [self connectedPort:theSocket];
	else
		return [self connectedPort:theSocket6];
}

- (NSString *)localHost {
	if(theSocket)
		return [self localHost:theSocket];
	else
		return [self localHost:theSocket6];
}

- (UInt16)localPort {
	if(theSocket)
		return [self localPort:theSocket];
	else
		return [self localPort:theSocket6];
}

- (NSString *)connectedHost:(CFSocketRef)socket {
	if (socket == NULL) return nil;
	CFDataRef peeraddr;
	NSString *peerstr = nil;
	
	if (socket && (peeraddr = CFSocketCopyPeerAddress(socket))) {
		peerstr = [self addressHost:peeraddr];
		CFRelease(peeraddr);
	}
	
	return peerstr;
}

- (UInt16)connectedPort:(CFSocketRef)socket {
	if (socket == NULL) return 0;
	CFDataRef peeraddr;
	UInt16 peerport = 0;

	if(socket && (peeraddr = CFSocketCopyPeerAddress(socket))) {
		peerport = [self addressPort:peeraddr];
		CFRelease(peeraddr);
	}

	return peerport;
}

- (NSString *)localHost:(CFSocketRef)socket {
	if (socket == NULL) return nil;
	CFDataRef selfaddr;
	NSString *selfstr = nil;

	if(socket && (selfaddr = CFSocketCopyAddress(socket))) {
		selfstr = [self addressHost:selfaddr];
		CFRelease(selfaddr);
	}

	return selfstr;
}

- (UInt16)localPort:(CFSocketRef)socket {
	if (socket == NULL) return 0;
	CFDataRef selfaddr;
	UInt16 selfport = 0;

	if (socket && (selfaddr = CFSocketCopyAddress(socket))) {
		selfport = [self addressPort:selfaddr];
		CFRelease(selfaddr);
	}

	return selfport;
}

- (BOOL)socketConnected {
	if(theSocket != NULL)
		return CFSocketIsValid(theSocket);
	else if(theSocket6 != NULL)
		return CFSocketIsValid(theSocket6);
	else
		return NO;
}

- (BOOL)streamsConnected {
	CFStreamStatus status;
	
	if (theReadStream != NULL) {
		status = CFReadStreamGetStatus(theReadStream);
		if (!(status == kCFStreamStatusOpen || status == kCFStreamStatusReading || status == kCFStreamStatusError)) return NO;
	} else return NO;

	if (theWriteStream != NULL) {
		status = CFWriteStreamGetStatus(theWriteStream);
		if (!(status == kCFStreamStatusOpen || status == kCFStreamStatusWriting || status == kCFStreamStatusError)) return NO;
	} else return NO;

	return YES;
}

- (NSString *)addressHost:(CFDataRef)cfaddr {
	if (cfaddr == NULL) return nil;
	
	char addrBuf[MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN)];
	struct sockaddr *pSockAddr = (struct sockaddr *)CFDataGetBytePtr(cfaddr);
	
	struct sockaddr_in *pSockAddrV4 = (struct sockaddr_in *)pSockAddr;
	struct sockaddr_in6 *pSockAddrV6 = (struct sockaddr_in6 *)pSockAddr;
	
	const void *pAddr = (pSockAddr->sa_family == AF_INET) ? (void *)(&(pSockAddrV4->sin_addr)) : (void *)(&(pSockAddrV6->sin6_addr));

	const char *pStr = inet_ntop(pSockAddr->sa_family, pAddr, addrBuf, sizeof(addrBuf));
	if (pStr == NULL) [NSException raise:NSInternalInconsistencyException format:@"Cannot convert address to string."];

	return [NSString stringWithCString:pStr encoding:NSASCIIStringEncoding];
}

- (UInt16)addressPort:(CFDataRef)cfaddr {
	if (cfaddr == NULL) return 0;
	struct sockaddr_in *pAddr = (struct sockaddr_in *)CFDataGetBytePtr(cfaddr);
	
	return ntohs(pAddr->sin_port);
}

- (NSString *)description {
	static const char *statstr[] = { "not open", "opening", "open", "reading", "writing", "at end", "closed", "has error" };
	CFStreamStatus rs = (theReadStream != NULL) ? CFReadStreamGetStatus (theReadStream) : 0;
	CFStreamStatus ws = (theWriteStream != NULL) ? CFWriteStreamGetStatus (theWriteStream) : 0;
	
	NSString *peerstr, *selfstr;
	CFDataRef peeraddr = NULL, peeraddr6 = NULL, selfaddr = NULL, selfaddr6 = NULL;

	if (theSocket || theSocket6) {
		if (theSocket != NULL) peeraddr  = CFSocketCopyPeerAddress(theSocket);
		if (theSocket6 != NULL) peeraddr6 = CFSocketCopyPeerAddress(theSocket6);
	
		if (theSocket6 && theSocket) {
			peerstr = [NSString stringWithFormat: @"%@/%@ %u", [self addressHost:peeraddr], [self addressHost:peeraddr6], [self addressPort:peeraddr]];
		} else if (theSocket6) {
			peerstr = [NSString stringWithFormat: @"%@ %u", [self addressHost:peeraddr6], [self addressPort:peeraddr6]];
		} else {
			peerstr = [NSString stringWithFormat: @"%@ %u", [self addressHost:peeraddr], [self addressPort:peeraddr]];
		}
		
		if (peeraddr) CFRelease(peeraddr);
		peeraddr = NULL;
		
		if(peeraddr6) CFRelease(peeraddr6);
		peeraddr6 = NULL;
	} else peerstr = @"nowhere";

	if (theSocket || theSocket6) {
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
	
	NSMutableString *ms = [NSMutableString string];
	[ms appendString: [NSString stringWithFormat:@"<AsyncSocket %p", self]];
	[ms appendString: [NSString stringWithFormat:@" local %@ remote %@ ", selfstr, peerstr]];
	[ms appendString: [NSString stringWithFormat:@"has queued %d reads %d writes, ", [theReadQueue count], [theWriteQueue count] ]];

	if (theCurrentRead == nil) [ms appendString: @"no current read, "];
	else {
		int percentDone;
		if ([theCurrentRead->buffer length] != 0)
			percentDone = (float)theCurrentRead->bytesDone / (float)[theCurrentRead->buffer length] * 100.0;
		else
			percentDone = 100;

		[ms appendString: [NSString stringWithFormat:@"currently read %u bytes (%d%% done), ", [theCurrentRead->buffer length], (theCurrentRead->bytesDone ? percentDone : 0)]];
	}

	if (theCurrentWrite == nil) [ms appendString: @"no current write, "];
	else {
		int percentDone;
		if ([theCurrentWrite->buffer length] != 0)
			percentDone = (float)theCurrentWrite->bytesDone /
						  (float)[theCurrentWrite->buffer length] * 100.0;
		else
			percentDone = 100;

		[ms appendString: [NSString stringWithFormat:@"currently written %u (%d%%), ", [theCurrentWrite->buffer length], (theCurrentWrite->bytesDone ? percentDone : 0)]];
	}
	
	[ms appendString: [NSString stringWithFormat:@"read stream %p %s, write stream %p %s", theReadStream, statstr [rs], theWriteStream, statstr [ws] ]];
	if ((flags & kDisconnectSoon) == kDisconnectSoon) [ms appendString: @", will disconnect soon"];
	if (![self isConnected]) [ms appendString: @", not connected"];

	[ms appendString: @">"];

	return ms;
}

#pragma mark Reading

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration; {
	if ((flags & kForbidStreamReadWrite) == kForbidStreamReadWrite) return;
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
	
	[theReadQueue addObject:packet];
	[self scheduleDequeueRead];
	
	[packet release];
}

/**
 * Puts a maybeDequeueRead on the run loop. 
 * An assumption here is that selectors will be performed consecutively within their priority.
**/
- (void)scheduleDequeueRead {
	[self performSelector:@selector(maybeDequeueRead) withObject:nil afterDelay:0];
}

/**
 * This method starts a new read, if needed.
 * It is called when a user requests a read,
 * or when a stream opens that may have requested reads sitting in the queue, etc.
**/
- (void)maybeDequeueRead {
	// If we're not currently processing a read AND
	// we have read requests sitting in the queue AND we have actually have a read stream
	if (theCurrentRead == nil && [theReadQueue count] != 0 && theReadStream != NULL) {
		// Get new current read AsyncReadPacket.
		AsyncReadPacket *newPacket = [theReadQueue objectAtIndex:0];
		theCurrentRead = [newPacket retain];
#warning investigate this apparent leak
		[theReadQueue removeObjectAtIndex:0];

		// Start time-out timer.
		if (theCurrentRead->timeout >= 0.0) {
			theReadTimer = [NSTimer scheduledTimerWithTimeInterval:(theCurrentRead->timeout) target:self selector:@selector(doReadTimeout:) userInfo:nil repeats:NO];
		}

		// Immediately read, if possible.
		[self doBytesAvailable];
	}
}

/**
 * Call this method in doBytesAvailable instead of CFReadStreamHasBytesAvailable().
 * This method supports pre-buffering properly.
**/
- (BOOL)hasBytesAvailable {
	return ([partialReadBuffer length] > 0) || CFReadStreamHasBytesAvailable(theReadStream);
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
		return CFReadStreamRead(theReadStream, buffer, length);
	}
}

/**
 * This method is called when a new read is taken from the read queue or when new data becomes available on the stream.
**/
- (void)doBytesAvailable {
	// If data is available on the stream, but there is no read request, then we don't need to process the data yet.
	// Also, if there is a read request, but no read stream setup yet, we can't process any data yet.
	if (theCurrentRead != nil && theReadStream != NULL) {
		CFIndex totalBytesRead = 0;
		
		BOOL done = NO;
		BOOL socketError = NO, maxoutError = NO;
		
		while (!done && !socketError && !maxoutError && [self hasBytesAvailable]) {
			BOOL didPreBuffer = NO;
			
			// If reading all available data, make sure there's room in the packet buffer.
			if (theCurrentRead->readAllAvailableData == YES) {
				// Make sure there is at least READALL_CHUNKSIZE bytes available.
				// We don't want to increase the buffer any more than this or we'll waste space.
				// With prebuffering it's possible to read in a small chunk on the first read.
				
				unsigned buffInc = READALL_CHUNKSIZE - ([theCurrentRead->buffer length] - theCurrentRead->bytesDone);
				[theCurrentRead->buffer increaseLengthBy:buffInc];
			}

			// If reading until data, we may only want to read a few bytes.
			// Just enough to ensure we don't go past our term or over our max limit.
			// Unless pre-buffering is enabled, in which case we may want to read in a larger chunk.
			if(theCurrentRead->term != nil)
			{
				// If we already have data pre-buffered, we obviously don't want to pre-buffer it again.
				// So in this case we'll just read as usual.
				
				if(([partialReadBuffer length] > 0) || !(flags & kEnablePreBuffering))
				{
					unsigned maxToRead = [theCurrentRead readLengthForTerm];
					
					unsigned bufInc = maxToRead - ([theCurrentRead->buffer length] - theCurrentRead->bytesDone);
					[theCurrentRead->buffer increaseLengthBy:bufInc];
				}
				else
				{
					didPreBuffer = YES;
					unsigned maxToRead = [theCurrentRead prebufferReadLengthForTerm];
					
					unsigned buffInc = maxToRead - ([theCurrentRead->buffer length] - theCurrentRead->bytesDone);
					[theCurrentRead->buffer increaseLengthBy:buffInc];

				}
			}
			
			// Number of bytes to read is space left in packet buffer.
			CFIndex bytesToRead = [theCurrentRead->buffer length] - theCurrentRead->bytesDone;
			
			// Read data into packet buffer
			UInt8 *subBuffer = (UInt8 *)([theCurrentRead->buffer mutableBytes] + theCurrentRead->bytesDone);
			CFIndex bytesRead = [self readIntoBuffer:subBuffer maxLength:bytesToRead];
			
			// Check results
			if(bytesRead < 0)
			{
				socketError = YES;
			}
			else
			{
				// Update total amound read for the current read
				theCurrentRead->bytesDone += bytesRead;
				
				// Update total amount read in this method invocation
				totalBytesRead += bytesRead;
			}

			// Is packet done?
			if(theCurrentRead->readAllAvailableData != YES)
			{
				if(theCurrentRead->term != nil)
				{
					if(didPreBuffer)
					{
						// Search for the terminating sequence within the big chunk we just read.
						CFIndex overflow = [theCurrentRead searchForTermAfterPreBuffering:bytesRead];
						
						if(overflow > 0)
						{
							// Copy excess data into partialReadBuffer
							NSMutableData *buffer = theCurrentRead->buffer;
							const void *overflowBuffer = [buffer bytes] + theCurrentRead->bytesDone - overflow;
							
							[partialReadBuffer appendBytes:overflowBuffer length:overflow];
							
							// Update the bytesDone variable.
							// Note: The completeCurrentRead method will trim the buffer for us.
							theCurrentRead->bytesDone -= overflow;
						}
						
						done = (overflow >= 0);
					}
					else
					{
						// Search for the terminating sequence at the end of the buffer
						int termlen = [theCurrentRead->term length];
						if(theCurrentRead->bytesDone >= termlen)
						{
							const void *buf = [theCurrentRead->buffer bytes] + (theCurrentRead->bytesDone - termlen);
							const void *seq = [theCurrentRead->term bytes];
							done = (memcmp (buf, seq, termlen) == 0);
						}
					}
					
					if(!done && theCurrentRead->maxLength >= 0 && theCurrentRead->bytesDone >= theCurrentRead->maxLength)
					{
						// There's a set maxLength, and we've reached that maxLength without completing the read
						maxoutError = YES;
					}
				}
				else
				{
					// Done when (sized) buffer is full.
					done = ([theCurrentRead->buffer length] == theCurrentRead->bytesDone);
				}
			}
			// else readAllAvailable doesn't end until all readable is read.
		}
		
		if (theCurrentRead->readAllAvailableData && theCurrentRead->bytesDone > 0)
			done = YES;	// Ran out of bytes, so the "read-all-data" type packet is done

		if (done) {
			[self completeCurrentRead];
			if (!socketError) [self scheduleDequeueRead];
		} else if (theCurrentRead->bytesDone > 0) {
			// We're not done with the readToLength or readToData yet, but we have read in some bytes
			if ([self.delegate respondsToSelector:@selector(socket:didReadPartialDataOfLength:tag:)]) {
				[self.delegate socket:self didReadPartialDataOfLength:totalBytesRead tag:(theCurrentRead->tag)];
			}
		}

		if (socketError) {
			CFStreamError err = CFReadStreamGetError(theReadStream);
			[self closeWithError:[self errorFromCFStreamError:err]];
			return;
		}
		
		if (maxoutError) {
			[self closeWithError:[self getReadMaxedOutError]];
			return;
		}
	}
}

// Ends current read and calls delegate.
- (void)completeCurrentRead {
	NSAssert(theCurrentRead, @"Trying to complete current read when there is no current read.");
	
	[theCurrentRead->buffer setLength:theCurrentRead->bytesDone];
	
	if ([self.delegate respondsToSelector:@selector(layer:didRead:forTag:)]) {
		[self.delegate layer:self didRead:(theCurrentRead->buffer) forTag:(theCurrentRead->tag)];
	}
	
	if (theCurrentRead != nil) [self endCurrentRead]; // Caller may have disconnected.
}

// Ends current read.
- (void)endCurrentRead {
	NSAssert(theCurrentRead != nil, @"Trying to end current read when there is no current read.");
	
	[theReadTimer invalidate];
	theReadTimer = nil;
	
	[theCurrentRead release];
	theCurrentRead = nil;
}

- (void)doReadTimeout:(NSTimer *)timer {
	if (timer != theReadTimer) return;
	
	if (theCurrentRead != nil) {
		[self endCurrentRead];
	}
	
	[self closeWithError:[self getReadTimeoutError]];
}

#pragma mark Writing

- (void)performWrite:(NSData *)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration; {
	if ((flags & kForbidStreamReadWrite) == kForbidStreamReadWrite) return;
	if (data == nil || [data length] == 0) return;
	
	AsyncWritePacket *packet = [[AsyncWritePacket alloc] initWithData:data timeout:duration tag:tag];
	
	[theWriteQueue addObject:packet];
	[self scheduleDequeueWrite];
	
	[packet release];
}

- (void)scheduleDequeueWrite {
	[self performSelector:@selector(maybeDequeueWrite) withObject:nil afterDelay:0];
}

// Start a new write.
- (void)maybeDequeueWrite {
	if (theCurrentWrite != nil || [theWriteQueue count] == 0 || theWriteStream == NULL) return;

	AsyncWritePacket *newPacket = [theWriteQueue objectAtIndex:0];
	theCurrentWrite = [newPacket retain];
	[theWriteQueue removeObjectAtIndex:0];
	
	// Start time-out timer.
	if (theCurrentWrite->timeout >= 0.0) {
		theWriteTimer = [NSTimer scheduledTimerWithTimeInterval:theCurrentWrite->timeout target:self selector:@selector(doWriteTimeout:) userInfo:nil repeats:NO];
	}
	
	[self doSendBytes];
}

- (void)doSendBytes {
	if (theCurrentWrite == nil || theWriteStream == NULL) return;

	BOOL done = NO, error = NO;
	while (!done && !error && CFWriteStreamCanAcceptBytes(theWriteStream)) {
		// Figure out what to write.
		CFIndex bytesRemaining = [theCurrentWrite->buffer length] - theCurrentWrite->bytesDone;
		CFIndex bytesToWrite = (bytesRemaining < WRITE_CHUNKSIZE) ? bytesRemaining : WRITE_CHUNKSIZE;
		UInt8 *writestart = (UInt8 *)([theCurrentWrite->buffer bytes] + theCurrentWrite->bytesDone);
		
		CFIndex bytesWritten = CFWriteStreamWrite(theWriteStream, writestart, bytesToWrite);
		
		if (bytesWritten < 0) {
			bytesWritten = 0;
			error = YES;
		}
		
		theCurrentWrite->bytesDone += bytesWritten;
		done = ([theCurrentWrite->buffer length] == theCurrentWrite->bytesDone);
	}
	
	if (done) {
		[self completeCurrentWrite];
		if (!error) [self scheduleDequeueWrite];
	}
	
	if (error) {
		CFStreamError err = CFWriteStreamGetError(theWriteStream);
		[self closeWithError:[self errorFromCFStreamError:err]];
	}
}

// End current write and call delegate
- (void)completeCurrentWrite {
	NSAssert(theCurrentWrite != nil, @"Trying to complete current write when there is no current write.");
	
	if ([self.delegate respondsToSelector:@selector(layer:didWrite:forTag:)]) {
		[self.delegate layer:self didWrite:theCurrentWrite->buffer forTag:theCurrentWrite->tag];
	}
	
	if (theCurrentWrite != nil) [self endCurrentWrite]; // Caller may have disconnected.
}

- (void)endCurrentWrite {
	NSAssert(theCurrentWrite != nil, @"Trying to complete current write when there is no current write.");
	
	[theWriteTimer invalidate];
	theWriteTimer = nil;
	
	[theCurrentWrite release];
	theCurrentWrite = nil;
	
	[self maybeScheduleDisconnect];
}

// Checks to see if all writes have been completed for disconnectAfterWriting.
- (void)maybeScheduleDisconnect {
	if ((flags & kDisconnectSoon) != kDisconnectSoon) return;
	
	if (([theWriteQueue count] == 0) && (theCurrentWrite == nil)) {
		[self performSelector:@selector(disconnect) withObject:nil afterDelay:0];
	}
}

- (void)doWriteTimeout:(NSTimer *)timer {
	if (timer != theWriteTimer) return; // Old timer. Ignore it.
	
	if (theCurrentWrite != nil) {
		[self endCurrentWrite];
	}
	
	[self closeWithError:[self getWriteTimeoutError]];
}

#pragma mark Callbacks

static void AFSocketStreamsSocketCallback(CFSocketRef sref, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	AFSocketStream *self = [[(AFSocketStream *)pInfo retain] autorelease];
	
	NSCAssert(((sref == self->theSocket) || (sref == self->theSocket6)), @"socket callback for a socket that doesn't belong to this object");
	
	switch (type) {
		case kCFSocketConnectCallBack:
			// The data argument is either NULL or a pointer to an SInt32 error code, if the connect failed.			
			[self doSocketOpen:sref withCFSocketError:(pData != NULL ? kCFSocketError : kCFSocketSuccess)];
			break;
		case kCFSocketAcceptCallBack:
			[self doAcceptWithSocket:*((CFSocketNativeHandle *)pData)];
			break;
		default:
			NSLog (@"%s, socket %p, received unexpected CFSocketCallBackType %d.", __PRETTY_FUNCTION__, self, type);
			break;
	}
	
	[pool release];
}

static void AFSocketStreamsReadStreamCallback(CFReadStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	AFSocketStream *self = [[(AFSocketStream *)pInfo retain] autorelease];
	
	NSCAssert((self->theReadStream != NULL), @"theReadStream is NULL");
	
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
			CFStreamError err = CFReadStreamGetError(self->theReadStream);
			[self closeWithError:[self errorFromCFStreamError:err]];
			break;
		}
		default:
			NSLog(@"AsyncSocket %p received unexpected CFReadStream callback, CFStreamEventType %d.", self, type);
			break;
	}
	
	[pool release];
}

static void AFSocketStreamsWriteStreamCallback(CFWriteStreamRef stream, CFStreamEventType type, void *pInfo) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	AFSocketStream *self = [[(AFSocketStream *)pInfo retain] autorelease];
	
	NSCAssert((self->theWriteStream != NULL), @"theWriteStream is NULL");
	
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
			CFStreamError err = CFWriteStreamGetError(self->theWriteStream);
			[self closeWithError:[self errorFromCFStreamError:err]];
			break;
		}
		default:
			NSLog(@"%s, socket %p, received unexpected CFWriteStream callback, CFStreamEventType %d.", __PRETTY_FUNCTION__, self, type);
			break;
	}
	
	[pool release];
}

@end
