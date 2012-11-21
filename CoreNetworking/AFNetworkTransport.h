//
//  AFNetworkTransport.h
//	Amber
//
//	Originally based on AsyncSocket <http://code.google.com/p/cocoaasyncsocket/>
//	Although the class is now much departed from the original codebase.
//
//  Created by Keith Duncan
//  Copyright 2008. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetworkConnectionLayer.h"

#import "CoreNetworking/AFNetwork-Types.h"

@class AFNetworkTransport;
@class AFNetworkStream;

@class AFNetworkPacketWrite;
@class AFNetworkPacketRead;

@protocol AFNetworkTransportControlDelegate <AFNetworkConnectionLayerControlDelegate>

@end

@protocol AFNetworkTransportDataDelegate <AFNetworkConnectionLayerDataDelegate>

 @optional

/*!
	\brief
	Instead of calling <tt>-currentWriteProgress...</tt> on a timer - which would be highly inefficient - you should implement this delegate method to be notified of write progress.
 */
- (void)networkTransport:(AFNetworkTransport *)transport didWritePartialDataOfLength:(NSInteger)partialBytes totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite context:(void *)context;

/*!
	\brief
	Instead of calling <tt>-currentReadProgress...</tt> on a timer - which would be highly inefficient - you should implement this delegate method to be notified of read progress.
 
	\param total
	Will be <tt>NSUIntegerMax</tt> if the packet terminator is a data pattern.
 */
- (void)networkTransport:(AFNetworkTransport *)transport didReadPartialDataOfLength:(NSInteger)partialBytes totalBytesRead:(NSInteger)totalBytesRead totalBytesExpectedToRead:(NSInteger)totalBytesExpectedToRead context:(void *)context;

@end

@protocol AFNetworkTransportDelegate <AFNetworkConnectionLayerDelegate, AFNetworkTransportControlDelegate, AFNetworkTransportDataDelegate>

@end

/*!
	\brief
	Primarily an extention of the CFSocketStream API. Originally named for that purpose as 'AFSocketStream' though the name was changed so not to imply the exclusive use of SOCK_STREAM.
	
	\details
	This class is a mix of two of the primary patterns:
	- Internally, it acts an adaptor between the CFSocketRef and CFStreamRef API.
	- Externally, it bridges CFHostRef and CFNetServiceRef with CFSocketRef and CFStreamRef providing an asyncronous CFStreamRef like API.
*/
@interface AFNetworkTransport : AFNetworkLayer <AFNetworkConnectionLayer> {
 @private
	union {
		AFNetworkServiceSignature _service;
		AFNetworkHostSignature _host;
	} _signature;
	
	AFNetworkStream *_writeStream;
	NSUInteger _writeFlags;
	
	AFNetworkStream *_readStream;
	NSUInteger _readFlags;
	
	NSUInteger _connectionFlags;
}

@property (assign, nonatomic) id <AFNetworkTransportDelegate> delegate;

/*!
	\brief
	This returns the local address of the connected stream.
 */
@property (readonly, nonatomic) id localAddress;

/*!
	\brief
	Depending on how the object was instantiated it may be a <tt>CFNetServiceRef</tt> or a <tt>CFHostRef</tt>
	For a remote-initiated steam, it will always be a <tt>CFHostRef</tt>.
 */
@property (readonly, nonatomic) CFTypeRef peer;

/*!
	\brief
	This returns the remote address of the connected stream.
 */
@property (readonly, nonatomic) id peerAddress;

@end
