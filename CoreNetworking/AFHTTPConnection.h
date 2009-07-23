//
//  HTTPConnection.h
//  CoreNetworking
//
//  Created by Keith Duncan on 29/04/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFNetworkConnection.h"

#import "CoreNetworking/AFConnectionLayer.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

@class AFPacketQueue;

/*!
	@brief
	This class is indended to sit on top of AFNetworkTransport and provides HTTP messaging semantics.
 */
@interface AFHTTPConnection : AFNetworkConnection <AFConnectionLayer> {	
	AFPacketQueue *_transactionQueue;
}

/*!
	@brief
	This method doesn't enqueue a transaction; it simply passes the data on to the |lowerLayer| for writing.
	This method allows for raw HTTP messaging without the implied request/response model.
 */
- (void)performWrite:(CFHTTPMessageRef)message forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

/*!
	@brief
	This method enqueues a transaction, which pairs a request with it's response.
	You will be notified via the delegate method <tt>-layer:didRead:forTag:</tt> when the response has been read.
	
	@result
	The data written to the socket, complete with the headers added internally.
 */
- (NSData *)performMethod:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body;

/*!
	@brief
	This enqueues a read transaction, it is shorthand for [connection performRead:nil forTag:0 withTimeout:-1]
 */
- (void)performRead;

@end

@interface AFHTTPConnection (Delegate) <AFTransportLayerControlDelegate, AFTransportLayerDataDelegate>

@end
