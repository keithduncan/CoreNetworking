//
//  AFHTTPServer.h
//  pangolin
//
//  Created by Keith Duncan on 01/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFNetworkServer.h"

@protocol AFHTTPServerDataDelegate;

extern NSString *const AFHTTPServerRenderersKey;

/*!
	@brief
	This is a simple HTTP server which attempts to return resources sourced through two means.
	It first consults the delegate to return a CFHTTPMessageRef response for a given request, if NULL 
 */
@interface AFHTTPServer : AFNetworkServer {
	NSArray *_renderers;
}

/*!
	@brief
	The objects in this collection must implement the AFHTTPServerRenderer protocol.
	
	@detail
	Each of these objects is consulted in order to render the resource, if NULL is returned the next is consulted.
 */
@property (readonly, retain) NSArray *renderers;

@end

@protocol AFHTTPServerDataDelegate <AFNetworkServerDelegate>

@end

@protocol AFHTTPServerRenderer <NSObject>

- (CFHTTPMessageRef)renderResourceForRequest:(CFHTTPMessageRef)request;

@end
