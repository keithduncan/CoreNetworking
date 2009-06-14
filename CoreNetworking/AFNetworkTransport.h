//
//  AFNetworkTransport.h
//	Amber
//
//	Originally based on AsyncSocket http://code.google.com/p/cocoaasyncsocket/
//	Although the class is now much departed from the original codebase.
//
//  Created by Keith Duncan
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetworkTypes.h"
#import "CoreNetworking/AFConnectionLayer.h"

@protocol AFNetworkTransportDataDelegate;
@protocol AFNetworkTransportControlDelegate;

@class AFPacketQueue;

struct _AFNetworkTransportStreamInfo {
	__strong id stream;
	NSUInteger flags;
	AFPacketQueue *queue;
};

/*!
    @brief
	Primarily an extention of the CFSocketStream API. Originally named for that purpose as 'AFSocketStream' though the name was changed so not to imply the exclusive use of SOCK_STREAM.
 
    @detail
	This class is a mix of two of the primary patterns. Internally, it acts an adaptor between the CFSocket and CFStream API.
	Externally, it bridges CFHost, CFNetService with CFSocket and CFStream. It provides a CFStream like API.
	
	Note: The layout of the _peer union is important, we can cast the _peer instance variable to CFTypeRef and introspect using CFGetTypeID to determine the struct in use.
*/
@interface AFNetworkTransport : AFNetworkLayer <AFConnectionLayer> {	
	NSUInteger _connectionFlags;
	
	union {
		struct AFNetworkTransportServiceSignature {
			__strong CFNetServiceRef netService;
		} _netServiceDestination;
		
		struct AFNetworkTransportPeerSignature _hostDestination;
	} _peer;
	
	struct _AFNetworkTransportStreamInfo _writeInfo;
	struct _AFNetworkTransportStreamInfo _readInfo;
}

@property (assign) id <AFNetworkTransportControlDelegate, AFNetworkTransportDataDelegate> delegate;

/*!
	@brief
	Depending on how the object was instantiated it may be a <tt>CFNetServiceRef</tt> or a <tt>CFHostRef</tt>
	If this is an inbound connection, it will always be a <tt>CFHostRef</tt>.
 */
@property (readonly) CFTypeRef peer;

/*!
	@brief
	All parameters are optional, allowing you to extract only the values you require.
 */
- (float)currentReadProgressWithBytesDone:(NSUInteger *)done bytesTotal:(NSUInteger *)total forTag:(NSUInteger *)tag;

/*!
	@brief
	All parameters are optional, allowing you to extract only the values you require.	
 */
- (float)currentWriteProgressWithBytesDone:(NSUInteger *)done bytesTotal:(NSUInteger *)total forTag:(NSUInteger *)tag;

@end

@protocol AFNetworkTransportControlDelegate <AFConnectionLayerControlDelegate>

 @optional

/*!
	@brief	When the socket is closing you can keep it open until the writes are complete, but you'll have to ensure the object remains live.
 */
- (BOOL)socket:(AFNetworkTransport *)socket shouldRemainOpenPendingWrites:(NSUInteger)count;

@end

@protocol AFNetworkTransportDataDelegate <AFTransportLayerDataDelegate>

 @optional

/*!
	@brief
	Instead of calling <tt>-currentReadProgress...</tt> on a timer - which would be highly inefficient - you should implement this delegate method to be notified of read progress.
 
	@param
	|total| will be NSUIntegerMax if the packet terminator is a data pattern.
 */
- (void)socket:(AFNetworkTransport *)socket didReadPartialDataOfLength:(NSUInteger)partialLength total:(NSUInteger)totalLength forTag:(NSInteger)tag;

/*!
	@brief
	Instead of calling <tt>-currentWriteProgress...</tt> on a timer - which would be highly inefficient - you should implement this delegate method to be notified of write progress.
 */
- (void)socket:(AFNetworkTransport *)socket didWritePartialDataOfLength:(NSUInteger)partialLength total:(NSUInteger)totalLength forTag:(NSInteger)tag;

@end
