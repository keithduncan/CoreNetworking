//
//  AFHTTPServer.h
//  pangolin
//
//  Created by Keith Duncan on 01/06/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkServer.h"

@class AFHTTPServer;

@protocol AFHTTPServerRenderer <NSObject>

/*!
	\brief
	When a request is received an object is asked to render a response
	
	\detail
	If no renderer returns a response the server generates a 404 response
 */
- (CFHTTPMessageRef)networkServer:(AFHTTPServer *)server renderResourceForRequest:(CFHTTPMessageRef)request;

@end

@protocol AFHTTPServerDataDelegate <AFNetworkServerDelegate>

 @optional

/*!
	\brief
	When a request is received an object is asked to render a response
	
	\detail
	If no renderer returns a response the server generates a 404 response
 */
- (CFHTTPMessageRef)networkServer:(AFHTTPServer *)server renderResourceForRequest:(CFHTTPMessageRef)request;

@end

/*!
	\brief
	This is a simple HTTP server which attempts to return resources sourced through two means.
	It first consults the delegate to return a CFHTTPMessageRef response for a given request, if NULL 
 */
@interface AFHTTPServer : AFNetworkServer {
 @private
	NSArray *_renderers;
}

/*!
	\brief
	The HTTP server delegate participates in the response rendering process.
 */
@property (assign, nonatomic) id <AFHTTPServerDataDelegate> delegate;

/*!
	\brief
	The renderers are consulted before the delegate
 */
@property (retain, nonatomic) NSArray *renderers;

@end
