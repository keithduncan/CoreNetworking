//
//  AFSocketStream.h
//
//  Created by Keith Duncan
//  Copyright 2008 thirty-three software. All rights reserved.
//
//	Adapted from AsyncSocket
//	http://code.google.com/p/cocoaasyncsocket/
//

#import "CoreNetworking/CoreNetworking.h"

@protocol AFSocketStreamDataDelegate;
@protocol AFSocketStreamControlDelegate;

enum {
	AFSocketStreamNoError = 0,
	AFSocketStreamCancelledError,
	AFSocketStreamReadMaxedOutError,
	AFSocketStreamReadTimeoutError,
	AFSocketStreamWriteTimeoutError,
};
typedef NSUInteger AFSocketStreamsError;

extern NSString *const AFSocketStreamErrorDomain;

/*!
    @struct 
    @abstract   Based on CFSocketSignature allowing for higher-level functionality
    @discussion This struct is missing the |protocolFamily| member from CFSocketSignature because the host is provided, it could resolve to a number of addresses of varying protocol family
 
	@field		|socketType| this should be one of SOCK_STREAM or SOCK_DGRAM, and places restrictions on the appropriate protocol
	@field		|protocol| this should be one of IPPROTO_TCP, IPPROTO_UDP, (future IPPROTO_SCTP) etc, it is important that an appropriate |socketType| is also provided
	@field      |host| this member is copied using CFHostCreateCopy() the addresses property is resolved if it hasn't been already. The member is qualified __strong, so that if this struct is stored on the heap it won't be reclaimed
	@field		|port| this identifies the Transport layer address to communicate using (see RFC 1122)
 */
struct _AFSocketSignature {
/*
 *	These define _how_ to communicate (and allow for the return of a specific handler subclass from the creation methods)
 */
	struct _AFSocketType {
		SInt32 socketType;
		SInt32 protocol;
	} _type;
/*
 *	These define _where_ to communicate
 */
	__strong CFHostRef host;
	SInt32 port;
};
typedef struct _AFSocketSignature AFSocketSignature;

extern struct _AFSocketType AFSocketTypeTCP;
extern struct _AFSocketType AFSocketTypeUDP;

/*!
    @class
    @abstract    An extention of the CFSocketStream API
    @discussion  This class is a mix of two primary patterns. Internally, it acts an adaptor and a bridge between the CFSocket and CFStream API. Externally, it bridges CFHost and CFSocket.
*/
@interface AFSocketStream : NSObject <AFConnectionLayer> {
	id _delegate;
	NSUInteger _flags;
	
	__strong CFRunLoopRef _runLoop;
	
#if 1
	/*
		These are only needed for a host socket
	 */
	__strong CFSocketRef _socket;
	__strong CFRunLoopSourceRef _socketRunLoopSource;
#endif
	
#if 1
	/*
	 These are only needed for a connect socket
	 */
	__strong CFHostRef _host;
	SInt32 _port;	
	
	__strong CFReadStreamRef readStream;
	NSMutableArray *readQueue;
	id _currentReadPacket;
	NSTimer *readTimer;
	
	NSMutableData *partialReadBuffer;
	
	__strong CFWriteStreamRef writeStream;
	NSMutableArray *writeQueue;
	id _currentWritePacket;
	NSTimer *writeTimer;
#endif
}

/*
 * Host Initialisers
 *	These return nil if the socket can't be created
 */

/*!
	@method
	@abstract	The socket is provided, this object takes ownership of the socket and listens for incoming connections
	@discussion	Only connections are listened for, no data is expected from the provided socket
 */
+ (id)hostSocket:(CFSocketRef)socket;

/*!
	@method
	@abstract	A socket is created with the given characteristics and the address is set
 */
+ (id)hostSocketWithSignature:(const CFSocketSignature *)signature;

/*
 * Connection Initialisers
 *	Perhaps the connection initialiser should be a class method as a facade to a class cluster and return TCP/UDP/SCTP internal subclasses?
 *	These connections will need to be sent -open before they can be used, just like a stream
 */

/*!
	@method
	@abstract	A resolved net service encapsulates all the data from the socket signature above
	@param		|netService| is copied using CFNetServiceCreateCopy()
 */
+ (id <AFNetworkLayer>)peerStreamWithNetService:(const CFNetServiceRef *)netService;

/*!
	@method
	@abstract	This doesn't use CFSocketSignature because the protocol family is determined by the CFHostRef address values
 */
+ (id <AFNetworkLayer>)peerStreamWithSignature:(const AFSocketSignature *)signature;


- (BOOL)canSafelySetDelegate;
@property (assign) id <AFSocketStreamControlDelegate, AFSocketStreamDataDelegate> delegate;

- (void)currentReadProgress:(float *)value tag:(NSUInteger *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total;
- (void)currentWriteProgress:(float *)value tag:(NSUInteger *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total;

- (void)enablePreBuffering;

- (NSData *)unreadData;

@end

@protocol AFSocketStreamControlDelegate <AFConnectionLayerControlDelegate>

 @optional

/*!
	@method
	@abstract	When the socket is closing you can keep it open until the writes are complete, you'll have to ensure the object remains live
 */
- (BOOL)streamShouldRemainOpenPendingWrites:(AFSocketStream *)stream;

/*!
	@method
	@abstract	Asynchronous callbacks can be scheduled in another run loop, defaults to CFRunLoopMain() if unimplemented
 */
- (CFRunLoopRef)streamShouldScheduleWithRunLoop:(AFSocketStream *)stream;

@end

@protocol AFSocketStreamDataDelegate <AFConnectionLayerDataDelegate>

 @optional

- (void)stream:(AFSocketStream *)stream didReadPartialDataOfLength:(CFIndex)partialLength tag:(long)tag;

@end
