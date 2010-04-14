//
//  HTTPConnection.h
//  CoreNetworking
//
//  Created by Keith Duncan on 29/04/2009.
//  Copyright 2009. All rights reserved.
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
 @private
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
	Overridable for subclasses, called for every request.
	
	@detail
	Adds the <tt>messageHeaders</tt>.
 */
- (void)preprocessRequest:(CFHTTPMessageRef)request;

/*
	Transaction Methods
	 These automatically enqueue a response, and are for replacing NSURLConnection functionality.
 */

/*!
	@brief
	This method enqueues a transaction, which pairs a request with it's response. The request may not be issued immediately.
	You will be notified via the delegate method <tt>-connection:didReceiveResponse:</tt> when the response has been read.
 */
- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body;

/*!
	@brief
	This method enqueues a transaction, which pairs a request with it's response. The request may not be issued immediately.
	This method may assist you in moving to a request/response model from the URL loading architecture in Cocoa.
	You will be notified via the delegate method <tt>-connection:didReceiveResponse:</tt> when the response has been read.
	
	@detail
	This is likely to be most useful where you already have a web service context, which vends preconstructed requests.
	
	@param request
	This method handles HTTP NSURLRequest objects with an HTTPBodyData, or HTTPBodyFile.
	If passed an NSURLRequest with an HTTPBodyStream, and exception is thrown.
 */
- (BOOL)performRequest:(NSURLRequest *)request error:(NSError **)errorRef;

/*
	Raw Messaging Methods
 */

/*!
	@brief
	This method doesn't enqueue a transaction; it simply passes the data on to the |lowerLayer| for writing.
	This method allows for raw HTTP messaging without starting the internal request/response matching.
 */
- (void)performRequestMessage:(CFHTTPMessageRef)message;

/*!
	@brief
	This enqueues a request reading packet, and is useful for servers and raw messaging.
 */
- (void)readRequest;

/*!
	@brief
	This enqueues a request reading packet, which writes the body to the location indicated, and is useful for raw messaging.
 */
- (void)downloadRequest:(NSURL *)location;

/*!
	@brief
	This serialises the response and writes it out over the wire.
	The connection wide headers will be appended to it.
 */
- (void)performResponseMessage:(CFHTTPMessageRef)message;

/*!
	@brief
	This enqueues a response reading packet, and is useful for raw messaging.
	The transaction enqueuing methods will call this after writing a request.
 */
- (void)readResponse;

/*!
	@brief
	This enqueues a response reading packet, which writes the body to the location indicated, and is useful for raw messaging.
 */
- (void)downloadResponse:(NSURL *)location;

@end

@interface AFHTTPConnection (AFAdditions)

/*!
	@brief
	Replaces NSURLDownload which can't be scheduled in multiple run loops and modes.
	
	@detail
	Transaction mode.
	Will handle large files by streaming them to disk.
 */
- (void)performDownload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation;

/*!
	@brief
	Counterpart to <tt>performDownload:onResource:withHeaders:withLocation:</tt>.
	
	@detail
	Transaction mode.
 */
- (BOOL)performUpload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation error:(NSError **)errorRef;

@end

@protocol AFHTTPConnectionDataDelegate <AFTransportLayerDataDelegate>

- (void)connection:(AFHTTPConnection *)connection didReceiveRequest:(CFHTTPMessageRef)request;

- (void)connection:(AFHTTPConnection *)connection didReceiveResponse:(CFHTTPMessageRef)response;

@end
