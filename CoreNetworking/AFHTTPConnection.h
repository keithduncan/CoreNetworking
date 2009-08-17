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
@protocol AFHTTPConnectionDataDelegate;

/*!
	@brief
	This class is indended to sit on top of AFNetworkTransport and provides HTTP messaging semantics.
 
	@detail
	It handles each request in series; and includes automatic behaviour for serveral responses:
 
	- 
 */
@interface AFHTTPConnection : AFNetworkConnection <AFConnectionLayer> {
	NSMutableDictionary *_messageHeaders;
	AFPacketQueue *_transactionQueue;
}

/*!
	@brief
	This property adds HTTP message data callbacks to the delegate.
 */
@property (assign) id <AFConnectionLayerControlDelegate, AFHTTPConnectionDataDelegate> delegate;

/*!
	@brief
	These headers will be added to each request/response written to the connection.
 
	@detail
	A client could add a 'User-Agent' header, likewise a server could add a 'Server' header.
 */
@property (readonly, retain) NSMutableDictionary *messageHeaders;

/*!
	@brief
	This method doesn't enqueue a transaction; it simply passes the data on to the |lowerLayer| for writing.
	This method allows for raw HTTP messaging without starting the internal request/response matching.
 
	@detail
	All messages written over the connection are funneled through this method so that the custom headers are added.
 */
- (void)performWrite:(CFHTTPMessageRef)message withTimeout:(NSTimeInterval)duration context:(void *)context;

/*
	Request Methods
 */

/*!
	@brief
	This method enqueues a transaction, which pairs a request with it's response. The request may not be issued immediately.
	You will be notified via the delegate method <tt>-connection:didReceiveResponse:</tt> when the response has been read.
	
	@result
	The data written to the socket, complete with the headers added internally.
 */
- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body;

/*!
	@brief
	This method enqueues a transaction, which pairs a request with it's response. The request may not be issued immediately.
	This method may assist you in moving to a request/response model from the URL loading architecture in Cocoa.
	You will be notified via the delegate method <tt>-connection:didReceiveResponse:</tt> when the response has been read.
 
	@detail
	This is likely to be most useful where you already have a web service context, which vends preconstructed requests.
 */
- (void)performRequest:(NSURLRequest *)request;

/*!
	@brief
	This enqueues a request reading packet, and is useful for servers and raw messaging.
 */
- (void)readRequest;

/*
	Response Methods
 */

/*!
	@brief
	This serialises the response and writes it out over the wire.
	The connection wide headers will be appended to it.
 */
- (void)performResponse:(CFHTTPMessageRef)message;

/*!
	@brief
	This enqueues a response reading packet, and is useful for raw messaging.
	The transaction enqueuing methods will call this after writing a request.
 */
- (void)readResponse;

@end

@protocol AFHTTPConnectionDataDelegate <AFTransportLayerDataDelegate>

- (void)connection:(AFHTTPConnection *)connection didReceiveRequest:(CFHTTPMessageRef)request;

- (void)connection:(AFHTTPConnection *)connection didReceiveResponse:(CFHTTPMessageRef)response;

@end
