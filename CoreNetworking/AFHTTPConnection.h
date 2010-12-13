//
//  HTTPConnection.h
//  CoreNetworking
//
//  Created by Keith Duncan on 29/04/2009.
//  Copyright 2009. All rights reserved.
//

#import "CoreNetworking/AFNetworkConnection.h"

#import "CoreNetworking/AFNetworkConnectionLayer.h"

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
@interface AFHTTPConnection : AFNetworkConnection <AFNetworkConnectionLayer> {
 @private
	NSMutableDictionary *_messageHeaders;
}

/*!
	\brief
	This property adds HTTP message data callbacks to the delegate.
 */
@property (assign) id <AFNetworkConnectionLayerControlDelegate, AFHTTPConnectionDataDelegate> delegate;

/*!
	\brief
	These headers will be added to each request/response written to the connection.
 
	\details
	A client could add a 'User-Agent' header, likewise a server could add a 'Server' header.
 */
@property (readonly, retain) NSMutableDictionary *messageHeaders;

/*
	Override Points
 */

/*!
	\brief
	Overridable for subclasses, called for every request.
	
	\details
	Adds the <tt>messageHeaders</tt>.
 */
- (void)preprocessRequest:(CFHTTPMessageRef)request;

/*!
	\brief
	Overridable for subclasses, called for every response.
	Call super for the default behaviour, which is to pass the response to the delegate.
 */
- (void)preprocessResponse:(CFHTTPMessageRef)response;

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

/*
	Lower layer overrides
 */

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didWrite:(id)data context:(void *)context;
- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didRead:(id)data context:(void *)context;

@end

@protocol AFHTTPConnectionDataDelegate <AFNetworkTransportLayerDataDelegate>

- (void)networkConnection:(AFHTTPConnection *)connection didReceiveRequest:(CFHTTPMessageRef)request;

- (void)networkConnection:(AFHTTPConnection *)connection didReceiveResponse:(CFHTTPMessageRef)response;

@end
