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

@class AFStreamPacketQueue;
@class AFPacketWrite;
@class AFPacketRead;

/*!
    @brief
	Primarily an extention of the CFSocketStream API. Originally named for that purpose as 'AFSocketStream' though the name was changed so not to imply the exclusive use of SOCK_STREAM.
	
    @detail
	This class is a mix of two of the primary patterns:
	• Internally, it acts an adaptor between the CFSocketRef and CFStreamRef API.
	• Externally, it bridges CFHostRef and CFNetServiceRef with CFSocketRef and CFStreamRef providing a CFStreamRef like API.
	
	Note: The layout of the _peer union is important, we can cast the _peer instance variable to CFTypeRef and introspect using CFGetTypeID to determine the struct in use.
*/
@interface AFNetworkTransport : AFNetworkLayer <AFConnectionLayer> {	
	NSUInteger _connectionFlags;
	
	union {
		AFNetworkTransportServiceSignature _netServiceDestination;
		AFNetworkTransportHostSignature _hostDestination;
	} _peer;
	
	AFStreamPacketQueue *_writeQueue;
	void *_writeQueueSource;
	
	AFStreamPacketQueue *_readQueue;
	void *_readQueueSource;
}

@property (assign) id <AFNetworkTransportControlDelegate, AFNetworkTransportDataDelegate> delegate;

/*!
	@brief
	This returns the local address of the connected stream.
 */
@property (readonly) id localAddress;

/*!
	@brief
	Depending on how the object was instantiated it may be a <tt>CFNetServiceRef</tt> or a <tt>CFHostRef</tt>
	For a remote-initiated steam, it will always be a <tt>CFHostRef</tt>.
 */
@property (readonly) CFTypeRef peer;

/*!
	@brief
	This returns the remote address of the connected stream.
 */
@property (readonly) id peerAddress;

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
	This method is called before a packet is actually enqueued.
 */
- (void)socket:(AFNetworkTransport *)socket willEnqueueReadPacket:(AFPacketRead *)packet;

/*!
	@brief
	Instead of calling <tt>-currentReadProgress...</tt> on a timer - which would be highly inefficient - you should implement this delegate method to be notified of read progress.
	
	@param
	|total| will be NSUIntegerMax if the packet terminator is a data pattern.
 */
- (void)socket:(AFNetworkTransport *)socket didReadPartialDataOfLength:(NSUInteger)partialLength total:(NSUInteger)totalLength context:(void *)context;

/*!
	@brief
	This method is called before a packet is actually enqueued.
	It allows you to tweak the chunk size for instance.
 */
- (void)socket:(AFNetworkTransport *)socket willEnqueueWritePacket:(AFPacketWrite *)packet;

/*!
	@brief
	Instead of calling <tt>-currentWriteProgress...</tt> on a timer - which would be highly inefficient - you should implement this delegate method to be notified of write progress.
 */
- (void)socket:(AFNetworkTransport *)socket didWritePartialDataOfLength:(NSUInteger)partialLength total:(NSUInteger)totalLength context:(void *)context;

@end
