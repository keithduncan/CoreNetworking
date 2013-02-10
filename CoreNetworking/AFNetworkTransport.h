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
@class AFNetworkStreamQueue;

@class AFNetworkPacketWrite;
@class AFNetworkPacketRead;

@protocol AFNetworkTransportControlDelegate <AFNetworkConnectionLayerControlDelegate>

@end

@protocol AFNetworkTransportDataDelegate <AFNetworkConnectionLayerDataDelegate>

 @optional

/*!
	\brief
	Instead of calling `-currentWriteProgress...` on a timer - which would be highly inefficient - you should implement this delegate method to be notified of write progress.
 */
- (void)networkTransport:(AFNetworkTransport *)transport didWritePartialDataOfLength:(NSInteger)partialBytes totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite context:(void *)context;

/*!
	\brief
	Instead of calling `-currentReadProgress...` on a timer - which would be highly inefficient - you should implement this delegate method to be notified of read progress.
 
	\param totalBytesExpectedToRead
	Will be `NSUIntegerMax` if the packet terminator is a data pattern.
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
	
	AFNetworkStreamQueue *_writeStream;
	NSUInteger _writeFlags;
	
	AFNetworkStreamQueue *_readStream;
	NSUInteger _readFlags;
	
	NSUInteger _connectionFlags;
}

@property (assign, nonatomic) id <AFNetworkTransportDelegate> delegate;

/*!
	\brief
	This returns the local address of the connected stream.
 */
@property (readonly, nonatomic) NSData *localAddress;

/*!
	\brief
	This returns the remote address of the connected stream.
 */
@property (readonly, nonatomic) NSData *peerAddress;

@end
