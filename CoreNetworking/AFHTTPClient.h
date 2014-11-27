//
//  AFHTTPClient.h
//  Amber
//
//  Created by Keith Duncan on 03/06/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif /* TARGET_OS_IPHONE */

#import "CoreNetworking/AFHTTPConnection.h"

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFHTTPClient;

@class AFNetworkPacketQueue;
@class AFHTTPTransaction;

@protocol AFHTTPClientDelegate

- (void)networkConnection:(AFHTTPClient *)connection didReceiveResponse:(CFHTTPMessageRef)response context:(void *)context;

@end

/*!
	\brief
	Adds request/response transaction tracking on top of AFHTTPConnection raw
	messaging.
 */
@interface AFHTTPClient : AFNetworkLayer {
 @private
	NSString *_userAgent;
	
	BOOL _shouldStartTLS;
	
	AFNetworkPacketQueue *_transactionQueue;
}

@property (assign, nonatomic) id <AFHTTPClientDelegate> delegate;

+ (NSString *)userAgent;
+ (void)setUserAgent:(NSString *)userAgent;

@property (copy, nonatomic) NSString *userAgent;

/*
	Transaction Methods
	
	These automatically enqueue reading a response.
 */

/*!
	\brief
	Enqueues a transaction, which pairs a request with it's response. The
	request may not be issued immediately.
 */
- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body context:(void *)context;

/*!
	\brief
	Enqueues a transaction, which pairs a request with it's response. The
	request may not be issued immediately.

	May assist you in moving to a request/response model from the URL loading
	architecture in Cocoa.

	\details
	This is likely to be most useful where you already have a web service
	context, which vends preconstructed requests.

	\param request
	Acceptable `NSURLRequest` objects are "HTTP" scheme with an `HTTPBodyData`,
	or `HTTPBodyFile`.

	If passed an NSURLRequest with an `HTTPBodyStream`, an exception is thrown.
 */
- (void)performRequest:(NSURLRequest *)request context:(void *)context;

/*
	Primitive
 */

/*!
	\brief
	Append your own request/response pair reading packets
 */
- (void)enqueueTransaction:(AFHTTPTransaction *)transaction;

@end
