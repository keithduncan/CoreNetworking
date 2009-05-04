//
//  AFSocket.h
//
//  Created by Keith Duncan
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetworkTypes.h"
#import "CoreNetworking/AFConnectionLayer.h"

@protocol AFSocketConnectionDataDelegate;
@protocol AFSocketConnectionControlDelegate;

/*!
    @class
    @abstract    Primarily an extention of the CFSocketStream API. Originally named for that purpose as 'AFSocketStream' though the 'stream' suffix was dropped so not to imply the exclusive use of SOCK_STREAM
    @discussion  This class is a mix of two of the primary patterns. Internally, it acts an adaptor between the CFSocket and CFStream API. Externally, it bridges CFHost, CFNetService with CFSocket and CFStream. It provides a CFStream like API.
*/
@interface AFSocketTransport : AFNetworkLayer <AFConnectionLayer> {	
	NSUInteger _connectionFlags;
	NSUInteger _streamFlags;
	
	union {
		struct {
			__strong CFNetServiceRef netService;
		} _netServiceDestination;
		
		struct AFSocketPeerSignature _hostDestination;
	} _peer;
	
	__strong CFReadStreamRef readStream;
	NSMutableArray *readQueue;
	id _currentReadPacket;
	
	__strong CFWriteStreamRef writeStream;
	NSMutableArray *writeQueue;
	id _currentWritePacket;
}

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
- (BOOL)socket:(AFSocketTransport *)socket shouldRemainOpenPendingWrites:(NSUInteger)count;

@end

@protocol AFSocketConnectionDataDelegate <AFNetworkLayerDataDelegate>

 @optional

/*!
	@method
	@abstract	instead of calling the <tt>-currentReadProgress:...</tt> on a timer, you can (optionally) implement this delegate method to be notified of read progress
	@param		|total| will be NSUIntegerMax if the packet terminator is a data pattern.
 */
- (void)socket:(AFSocketTransport *)socket didReadPartialDataOfLength:(NSUInteger)partialLength total:(NSUInteger)totalLength forTag:(NSInteger)tag;

/*!
	@method
	@abstract	instead of calling the <tt>-currentWriteProgress:...</tt> on a timer, you can (optionally) implement this delegate method to be notified of write progress
 */
- (void)socket:(AFSocketTransport *)socket didWritePartialDataOfLength:(NSUInteger)partialLength total:(NSUInteger)totalLength forTag:(NSInteger)tag;

@end
