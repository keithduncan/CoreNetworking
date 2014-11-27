//
//  HTTPConnection.h
//  CoreNetworking
//
//  Created by Keith Duncan on 29/04/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif /* TARGET_OS_IPHONE */

#import "CoreNetworking/AFNetworkConnection.h"

@class AFHTTPConnection;

@protocol AFHTTPConnectionDataDelegate

- (void)networkConnection:(AFHTTPConnection *)connection didReceiveRequest:(CFHTTPMessageRef)request;

- (void)networkConnection:(AFHTTPConnection *)connection didReceiveResponse:(CFHTTPMessageRef)response;

@end

/*!
	\brief
	Provides HTTP request/response messaging semantics.
	
	\details
	It handles each request in series.
 */
@interface AFHTTPConnection : AFNetworkConnection {
 @private
	NSMutableDictionary *_messageHeaders;
}

/*!
	\brief
	This property adds HTTP message data callbacks to the delegate.
 */
@property (assign, nonatomic) id <AFHTTPConnectionDataDelegate> delegate;

/*!
	\brief
	These headers will be added to each request/response written to the connection.
 
	\details
	A client could add a 'User-Agent' header, likewise a server could add a
	'Server' header.
 */
@property (readonly, retain, nonatomic) NSMutableDictionary *messageHeaders;

/*
	Override Points
 */

/*!
	\brief
	Overridable for subclasses, before a message is sent.
	
	\details
	Adds the `messageHeaders` and a "Content-Length" header.
 */
- (void)prepareMessageForTransport:(CFHTTPMessageRef)message;

/*!
	\brief
	Overridable for subclasses, called to return a message to the delegate.
 */
- (void)processMessageFromTransport:(CFHTTPMessageRef)message;

/*
	Requests
 */

/*!
	\brief
	Allows for raw HTTP messaging without starting the internal request/response
	matching.
 */
- (void)performRequestMessage:(CFHTTPMessageRef)message;

/*!
	\brief
	This enqueues a request reading packet, and is useful for servers and raw
	messaging.
 */
- (void)readRequest;

/*
	Responses
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

@end
