//
//  AFHTTPClient.h
//  Amber
//
//  Created by Keith Duncan on 03/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "CoreNetworking/AFHTTPConnection.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

@class AFNetworkPacketQueue;
@protocol AFHTTPClientDelegate;

/*!
	\brief
	Replaces NSURLConnection for HTTP NSURLRequest objects.
 */
@interface AFHTTPClient : AFHTTPConnection {
 @private
	NSString *_userAgent;
	
	__strong CFHTTPAuthenticationRef _authentication;
	NSDictionary *_authenticationCredentials;
	
	BOOL _shouldStartTLS;
	
	AFNetworkPacketQueue *_transactionQueue;
}

@property (assign) id <AFHTTPClientDelegate> delegate;

+ (NSString *)userAgent;
+ (void)setUserAgent:(NSString *)userAgent;

@property (copy) NSString *userAgent;

@property (retain) __strong __attribute__((NSObject)) CFHTTPAuthenticationRef authentication;
@property (copy) NSDictionary *authenticationCredentials;

/*
	Transaction Methods
		These automatically enqueue reading a response.
 */

/*!
	\brief
	This method enqueues a transaction, which pairs a request with it's response. The request may not be issued immediately.
 */
- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body context:(void *)context;

/*!
	\brief
	This method enqueues a transaction, which pairs a request with it's response. The request may not be issued immediately.
	This method may assist you in moving to a request/response model from the URL loading architecture in Cocoa.
	
	\details
	This is likely to be most useful where you already have a web service context, which vends preconstructed requests.
	
	\param request
	This method handles HTTP NSURLRequest objects with an HTTPBodyData, or HTTPBodyFile.
	If passed an NSURLRequest with an HTTPBodyStream, an exception is thrown.
 */
- (void)performRequest:(NSURLRequest *)request context:(void *)context;

/*!
	\brief
	Replaces NSURLDownload which can't be scheduled in multiple run loops or modes.
	
	\details
	Will handle large files by streaming them to disk.
 */
- (void)performDownload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation context:(void *)context;

/*!
	\brief
	Counterpart to <tt>performDownload:onResource:withHeaders:withLocation:</tt>.
	
	\details
	Will handle large files by streaming them from disk.
 */
- (BOOL)performUpload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation context:(void *)context error:(NSError **)errorRef;

@end


@protocol AFHTTPClientDelegate <AFHTTPConnectionDataDelegate>

- (void)networkConnection:(AFHTTPClient *)connection didReadResponse:(CFHTTPMessageRef)response context:(void *)context;

@end
