//
//  AFSocket.h
//
//  Created by Keith Duncan
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/CoreNetworking.h"

@protocol AFSocketConnectionDataDelegate;
@protocol AFSocketConnectionControlDelegate;

enum {
	AFSocketConnectionNoError				= 0,
	AFSocketConnectionAbortError			= 1,
	AFSocketConnectionReadTimeoutError	= 2,
	AFSocketConnectionWriteTimeoutError	= 3,
};
typedef NSUInteger AFSocketConnectionError;

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
 *	These define _where_ to communicate
 */
	__strong CFHostRef host;
	SInt32 port;
/*
 *	This defines _how_ to communicate (and allow for the return of a specific handler subclass from the creation methods)
 */
	struct AFSocketType type;
};
typedef struct AFSocketSignature AFSocketSignature;

/*!
    @class
    @abstract    Primarily an extention of the CFSocketStream API. Originally named for that purpose as 'AFSocketStream' though the 'stream' suffix was dropped so not to imply the exclusive use of SOCK_STREAM
    @discussion  This class is a mix of two of the primary patterns. Internally, it acts an adaptor between the CFSocket and CFStream API. Externally, it bridges CFHost, CFNetService with CFSocket and CFStream. It provides a CFStream like API.
*/
@interface AFSocketConnection : NSObject <AFConnectionLayer> {
	NSUInteger _connectionFlags;
	NSUInteger _streamFlags;
	
	union {
		struct {
			__strong CFNetServiceRef netService;
		} _netServiceDestination;
		
		struct AFSocketSignature _hostDestination;
	} _peer;
	
	__strong CFReadStreamRef readStream;
	NSMutableArray *readQueue;
	id _currentReadPacket;
	
	__strong CFWriteStreamRef writeStream;
	NSMutableArray *writeQueue;
	id _currentWritePacket;
}

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

/*!
	@method
	@abstract	will return YES if there are no pending writes/reads
 */
- (BOOL)canSafelySetDelegate;

/*!
	@property
 */
@property (assign) id <AFSocketConnectionControlDelegate, AFSocketConnectionDataDelegate> delegate;

/*!
	@method
	@abstract	all parameters are optional, allowing you to extract only the values you require
 */
- (void)currentReadProgress:(float *)fraction bytesDone:(NSUInteger *)done total:(NSUInteger *)total tag:(NSUInteger *)tag;

/*!
	@method
	@abstract	all parameters are optional, allowing you to extract only the values you require	
 */
- (void)currentWriteProgress:(float *)fraction bytesDone:(NSUInteger *)done total:(NSUInteger *)total tag:(NSUInteger *)tag;

@end

@protocol AFSocketConnectionControlDelegate <AFConnectionLayerControlDelegate>

 @optional

/*!
	@method
	@abstract	When the socket is closing you can keep it open until the writes are complete, but you'll have to ensure the object remains live
 */
- (BOOL)socketShouldRemainOpenPendingWrites:(AFSocketConnection *)socket;

@end

@protocol AFSocketConnectionDataDelegate <AFNetworkLayerDataDelegate>

 @optional

/*!
	@method
	@abstract	instead of calling the <tt>-currentReadProgress:...</tt> on a timer, you can (optionally) implement this delegate method to be notified of read progress
 */
- (void)socket:(AFSocketConnection *)socket didReadPartialDataOfLength:(NSUInteger)partialLength tag:(NSInteger)tag;

/*!
	@method
	@abstract	instead of calling the <tt>-currentWriteProgress:...</tt> on a timer, you can (optionally) implement this delegate method to be notified of write progress
 */
- (void)socket:(AFSocketConnection *)socket didWritePartialDataOfLength:(NSUInteger)partialLength tag:(NSInteger)tag;

@end
