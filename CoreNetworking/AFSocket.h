//
//  AFSocket.h
//
//  Created by Keith Duncan
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/CoreNetworking.h"

@protocol AFSocketDataDelegate;
@protocol AFSocketControlDelegate;

enum {
	AFSocketNoError				= 0,
	AFSocketAbortError			= 1,
	AFSocketReadMaxedOutError	= 2,
	AFSocketReadTimeoutError	= 3,
	AFSocketWriteTimeoutError	= 4,
};
typedef NSUInteger AFSocketError;

extern NSString *const AFSocketErrorDomain;

/*!
	@struct 
	@abstract   Based on CFSocketSignature allowing for higher-level functionality
	@discussion Doesn't include a |protocolFamily| field like CFSocketSignature because the |host| may resolve to a number of different protocol family addresses
	
	@field		|socketType| should be one of the socket types defined in <socket.h>
	@field		|protocol| should typically be one of the IP protocols defined in RFC 1700 see http://www.faqs.org/rfcs/rfc1700.html - it is important that an appropriate |socketType| is also provided
	@field      |host| is copied using CFHostCreateCopy() the addresses property is resolved if it hasn't been already. The member is qualified __strong, so that if this struct is stored on the heap it won't be reclaimed
	@field		|port| identifies the Transport layer address to communicate using (see RFC 1122)
 */
struct AFSocketSignature {
/*
 *	These define _how_ to communicate (and allow for the return of a specific handler subclass from the creation methods)
 */
	struct AFSocketType {
		SInt32 socketType;
		SInt32 protocol;
	} type;
/*
 *	These define _where_ to communicate
 */
	__strong CFHostRef host;
	SInt32 port;
};
typedef struct AFSocketSignature AFSocketSignature;

extern struct AFSocketType AFSocketTypeTCP;
extern struct AFSocketType AFSocketTypeUDP;

/*!
    @class
    @abstract    Primarily an extention of the CFSocketStream API. Originally named for that purpose as 'AFSocketStream' though the 'stream' suffix was dropped so not to imply the exclusive use of SOCK_STREAM
    @discussion  This class is a mix of two primary patterns. Internally, it acts an adaptor and a bridge between the CFSocket and CFStream API. Externally, it bridges CFHost, CFNetService and CFSocket with a CFStream like API.
*/
@interface AFSocket : NSObject <AFConnectionLayer> {
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
	union {
		struct {
			__strong CFNetServiceRef netService;
		} _netServiceDestination;
		
		struct _AFSocketSignature _hostDestination;
	} _peer;
	
	__strong CFReadStreamRef readStream;
	NSMutableArray *readQueue;
	id _currentReadPacket;
	
	__strong CFWriteStreamRef writeStream;
	NSMutableArray *writeQueue;
	id _currentWritePacket;
#endif
}

/*
 * Host Initialisers
 *	These return nil if the socket can't be created
 */

/*!
	@method
	@abstract	A socket is created with the given characteristics and the address is set
 */
+ (id)hostWithSignature:(const CFSocketSignature *)signature;

/*
 * Connection Initialisers
 *	Perhaps the connection initialiser should be a class method a facade to a class cluster and return SOCK_STREAM/SOCK_DGRAM etc internal subclasses?
 *	These connections will need to be sent -open before they can be used, just like a stream
 */

/*!
	@method
	@abstract	A resolved net service encapsulates all the data from the socket signature above
	@param		|netService| will be used to create a CFNetService internally for resolving
 */
+ (id <AFNetworkLayer>)peerWithNetService:(id <AFNetServiceCommon>)netService;

/*!
	@method
	@abstract	This doesn't use CFSocketSignature because the protocol family is determined by the CFHostRef address values
 */
+ (id <AFNetworkLayer>)peerWithSignature:(const AFSocketSignature *)signature;


- (BOOL)canSafelySetDelegate;
@property (assign) id <AFSocketControlDelegate, AFSocketDataDelegate> delegate;

- (void)currentReadProgress:(float *)value tag:(NSUInteger *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total;
- (void)currentWriteProgress:(float *)value tag:(NSUInteger *)tag bytesDone:(CFIndex *)done total:(CFIndex *)total;

@end

@protocol AFSocketControlDelegate <AFConnectionLayerControlDelegate>

 @optional

/*!
	@method
	@abstract	When the socket is closing you can keep it open until the writes are complete, but you'll have to ensure the object remains live
 */
- (BOOL)socketShouldRemainOpenPendingWrites:(AFSocket *)socket;

/*!
	@method
	@abstract	Asynchronous callbacks can be scheduled in another run loop, defaults to CFRunLoopMain() if unimplemented
	@discussion	This is done in a delegate callback to remove the burden of scheduling newly spawned accept() sockets
 */
- (CFRunLoopRef)socketShouldScheduleWithRunLoop:(AFSocket *)socket;

@end

@protocol AFSocketDataDelegate <AFConnectionLayerDataDelegate>

 @optional

- (void)socket:(AFSocket *)socket didReadPartialDataOfLength:(CFIndex)partialLength tag:(NSInteger)tag;

@end
