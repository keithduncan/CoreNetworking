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

@protocol AFHTTPConnectionDataDelegate;

/*!
	\brief
	This class is indended to sit on top of AFNetworkTransport and provides HTTP messaging semantics.
 
	\details
	It handles each request in series; and includes automatic behaviour for serveral responses:
 
	- 
 */
@interface AFHTTPConnection : AFNetworkConnection <AFConnectionLayer> {
 @private
	NSMutableDictionary *_messageHeaders;
}

/*!
	\brief
	This property adds HTTP message data callbacks to the delegate.
 */
@property (assign) id <AFConnectionLayerControlDelegate, AFHTTPConnectionDataDelegate> delegate;

/*!
	\brief
	These headers will be added to each request/response written to the connection.
 
	\details
	A client could add a 'User-Agent' header, likewise a server could add a 'Server' header.
 */
@property (readonly, retain) NSMutableDictionary *messageHeaders;

/*!
	\brief
	Overridable for subclasses, called for every request.
	
	\details
	Adds the <tt>messageHeaders</tt>.
 */
- (void)preprocessRequest:(CFHTTPMessageRef)request;

/*
	Request
 */

/*!
	\brief
	This method allows for raw HTTP messaging without starting the internal request/response matching.
 */
- (void)performRequestMessage:(CFHTTPMessageRef)message;

/*!
	\brief
	This enqueues a request reading packet, and is useful for servers and raw messaging.
 */
- (void)readRequest;

/*!
	\brief
	This enqueues a request reading packet, which writes the body to the location indicated, and is useful for raw messaging.
 */
- (void)downloadRequest:(NSURL *)location;

/*
	Response
 */

/*!
	\brief
	This serialises the response and writes it out over the wire.
	The connection wide headers will be appended to it.
 */
- (void)performResponseMessage:(CFHTTPMessageRef)message;

/*!
	\brief
	This enqueues a response reading packet, and is useful for raw messaging.
 */
- (void)readResponse;

/*!
	\brief
	This enqueues a response reading packet, which writes the body to the location indicated, and is useful for raw messaging.
 */
- (void)downloadResponse:(NSURL *)location;

/*
	Overrides
 */

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data context:(void *)context;
- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data context:(void *)context;

@end

@protocol AFHTTPConnectionDataDelegate <AFTransportLayerDataDelegate>

- (void)connection:(AFHTTPConnection *)connection didReceiveRequest:(CFHTTPMessageRef)request;

- (void)connection:(AFHTTPConnection *)connection didReceiveResponse:(CFHTTPMessageRef)response;

@end
