//
//  AFSocket.h
//
//  Created by Keith Duncan
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkTypes.h"
#import "CoreNetworking/AFConnectionLayer.h"
#import "CoreNetworking/AFNetService.h"

@protocol AFSocketConnectionDataDelegate;
@protocol AFSocketConnectionControlDelegate;

enum {
	AFSocketConnectionNoError				= 0,
	AFSocketConnectionReachabilityError		= 1,
	AFSocketConnectionAbortError			= 2,
	AFSocketConnectionReadTimeoutError		= 3,
	AFSocketConnectionWriteTimeoutError		= 4,
	AFSocketConnectionTLSError				= 5,
};
typedef NSUInteger AFSocketConnectionError;

/*!
	@struct 
	@abstract   Based on CFSocketSignature allowing for higher-level functionality
	@discussion Doesn't include a |protocolFamily| field like CFSocketSignature because the |host| may resolve to a number of different protocol family addresses
	@field      |host| is copied using CFHostCreateCopy() the addresses property is resolved if it hasn't been already. The member is qualified __strong, so that if this struct is stored on the heap it won't be reclaimed
	@field		|transport| see the documentation for <tt>AFSocketTransportLayer</tt> it encapsulates the transport type (TCP/UDP/SCTP/DCCP etc) and the port
 */
struct AFSocketSignature {
/*
 *	This defines _where_ to communicate
 */
	__strong CFHostRef host;
/*
 *	This defines _how_ to communicate (and may allow for the return of a specific handler subclass from the creation methods)
 */	
	AFSocketTransport transport;
};
typedef struct AFSocketSignature AFSocketSignature;

/*!
    @class
    @abstract    Primarily an extention of the CFSocketStream API. Originally named for that purpose as 'AFSocketStream' though the 'stream' suffix was dropped so not to imply the exclusive use of SOCK_STREAM
    @discussion  This class is a mix of two of the primary patterns. Internally, it acts an adaptor between the CFSocket and CFStream API. Externally, it bridges CFHost, CFNetService with CFSocket and CFStream. It provides a CFStream like API.
*/
@interface AFSocketConnection : NSObject <AFConnectionLayer> {
	id <AFNetworkLayer> lowerLayer;
	
	id <AFSocketConnectionControlDelegate, AFSocketConnectionDataDelegate> _delegate;
	
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
 *	Inbound Initialisers
 *		These are used when you have an accept socket that has spawned a new connection
 */

/*!
	@method
 */
- (id)initWithLowerLayer:(id <AFNetworkLayer>)layer;

/*
 * Outbound Initialisers
 *	Perhaps the connection initialiser should be a class method a facade to a class cluster and return SOCK_STREAM/SOCK_DGRAM etc internal subclasses?
 *	These connections will need to be sent -open before they can be used, just like a stream
 */

/*!
	@method
	@abstract	This doesn't use CFSocketSignature because the protocol family is determined by the CFHostRef address values
 */
- (id <AFConnectionLayer>)initWithSignature:(const AFSocketSignature *)signature;

/*!
	@method
	@abstract	This initialiser is a sibling to <tt>-initWithSignature:</tt>
	@discussion	A net service once resolved, encapsulates all the data from <tt>AFSocketSignature</tt>
	@param		|netService| will be used to create a CFNetService internally
 */
- (id <AFConnectionLayer>)initWithNetService:(id <AFNetServiceCommon>)netService;

/*!
	@property
 */
@property (assign) id <AFSocketConnectionControlDelegate, AFSocketConnectionDataDelegate> delegate;

/*!
	@property
	@abstract	Depending on how the object was instantiated it may be a <tt>CFNetServiceRef</tt> or a <tt>CFHostRef</tt>
				If this is an inbound connection, it will always be a <tt>CFHostRef</tt>
 */
@property (readonly) CFTypeRef peer;

/*!
	@method
	@abstract	all parameters are optional, allowing you to extract only the values you require
 */
- (float)currentReadProgressWithBytesDone:(NSUInteger *)done bytesTotal:(NSUInteger *)total forTag:(NSUInteger *)tag;

/*!
	@method
	@abstract	all parameters are optional, allowing you to extract only the values you require	
 */
- (float)currentWriteProgressWithBytesDone:(NSUInteger *)done bytesTotal:(NSUInteger *)total forTag:(NSUInteger *)tag;

@end

@protocol AFSocketConnectionControlDelegate <AFConnectionLayerControlDelegate>

 @optional

/*!
	@method
	@abstract	When the socket is closing you can keep it open until the writes are complete, but you'll have to ensure the object remains live
 */
- (BOOL)socket:(AFSocketConnection *)socket shouldRemainOpenPendingWrites:(NSUInteger)count;

@end

@protocol AFSocketConnectionDataDelegate <AFNetworkLayerDataDelegate>

 @optional

/*!
	@method
	@abstract	instead of calling the <tt>-currentReadProgress:...</tt> on a timer, you can (optionally) implement this delegate method to be notified of read progress
	@param		|total| will be NSUIntegerMax if the packet terminator is a data pattern.
 */
- (void)socket:(AFSocketConnection *)socket didReadPartialDataOfLength:(NSUInteger)partialLength total:(NSUInteger)totalLength forTag:(NSInteger)tag;

/*!
	@method
	@abstract	instead of calling the <tt>-currentWriteProgress:...</tt> on a timer, you can (optionally) implement this delegate method to be notified of write progress
 */
- (void)socket:(AFSocketConnection *)socket didWritePartialDataOfLength:(NSUInteger)partialLength total:(NSUInteger)totalLength forTag:(NSInteger)tag;

@end
