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

@protocol AFHTTPServerDataDelegate <AFNetworkServerDelegate>

 @optional

/*!
	\brief
	When a request is received the delegate is asked to render a response
	
	\detail
	If unimplemented, a 404 response code is returned
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

@end
