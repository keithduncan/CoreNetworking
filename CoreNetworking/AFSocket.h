//
//  AFSocketStream
//
//	Based on AsyncSocket
//  Renamed to AFSocketStream, API changed, and included in Core Networking by Keith Duncan
//  Original host http://code.google.com/p/cocoaasyncsocket/
//

#import "CoreNetworking/CoreNetworking.h"

@protocol AFSocketStreamDataDelegate;
@protocol AFSocketStreamControlDelegate;


enum {
	AFSocketStreamNoError = 0,
	AFSocketStreamCanceledError,
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
    @field      |host| this member is copied using CFHostCreateCopy() the addresses property is resolved if it hasn't been already
	@field		|port| this identifies the Transport layer address to communicate using (see RFC 1122)
	@field		|socketType| this should be one of SOCK_STREAM or SOCK_DGRAM, and places restrictions on the appropriate protocol
	@field		|protocol| this should be one of IPPROTO_TCP, IPPROTO_UDP, (future IPPROTO_SCTP) etc, it is important that an appropriate |socketType| is also provided
*/
struct _AFSocketSignature {
/*
 *	These define _where_ to communicate
 */
	__strong CFHostRef host;
	SInt32 port;
/*
 *	These define _how_ to communicate (and allow for the return of a specific handler subclass from the creation methods)
 */
	SInt32 socketType;
	SInt32 protocol;
};
typedef struct _AFSocketSignature AFSocketSignature;


/*!
    @class
    @abstract    An extention of the CFSocketStream API
    @discussion  This class is a mix of two primary patterns. Internally, it acts an adaptor and a bridge between the CFSocket and CFStream API. Externally, it bridges CFHost and CFSocket.
*/

@interface AFSocket : NSObject <AFConnectionLayer> {
	id _delegate;
	NSUInteger _flags;
	
#if 1
	/*
		These are only needed for a host socket
	 */
	__strong CFSocketRef _socket;
	
	__strong CFRunLoopRef _runLoop;
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
 * Connection Initialisers
 *	Perhaps the connection initialiser should be a class method as a facade to a class cluster and return TCP/UDP/SCTP internal subclasses?
 *	These connections will need to be sent -open before they can be used, just like a stream
 */

/*!
	@method
	@abstract	This doesn't use CFSocketSignature because the protocol family is determined by the CFHostRef resolution, not a predetermined value
	@discussion	
 */
+ (id)peerSocketWithSignature:(const AFSocketSignature *)signature;

/*!
	@method
	@abstract	A resolved net service encapsulates all the data from the socket signature above
	@param		|netService| is copied using CFNetServiceCreateCopy()
 */
+ (id)peerSocketWithNetService:(const CFNetServiceRef *)netService;

/*
 * Host Initialisers
 *	These return nil if the socket couldn't be created
 */

/*!
	@method
	@abstract	The socket is provided, this object takes ownership of the socket and listens for incoming data/connections
 */
+ (id)hostWithSocket:(CFSocketRef)socket;

/*!
	@method
	@abstract	A socket is created with the characteristics and the address will be set
 */
+ (id)hostWithSignature:(const CFSocketSignature *)signature;


- (BOOL)canSafelySetDelegate;
@property (assign) id <AFSocketStreamControlDelegate, AFSocketStreamDataDelegate> delegate;

/*
 * Note: this will be removed
 */
- (CFSocketRef)lowerLayer __attribute__((deprecated));

- (void)disconnectAfterWriting;

- (float)progressOfReadReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total;
- (float)progressOfWriteReturningTag:(long *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total;

- (void)enablePreBuffering;

- (NSData *)unreadData;

@end

@protocol AFSocketStreamControlDelegate <AFConnectionLayerControlDelegate>

 @optional

/*!
	@method
	@abstract	Asynchronous callbacks can be scheduled in another run loop, defaults to CFRunLoopMain() if unimplemented
 */
- (CFRunLoopRef)layerShouldScheduleWithRunLoop:(id <AFConnectionLayer>)layer;

@end

@protocol AFSocketStreamDataDelegate <AFConnectionLayerDataDelegate>

 @optional

- (void)layer:(AFSocket *)stream didReadPartialDataOfLength:(CFIndex)partialLength tag:(long)tag;

@end
