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

@class AFPacketQueue;

@interface AFHTTPClient : AFHTTPConnection {
 @private
	__strong CFHTTPAuthenticationRef _authentication;
	NSDictionary *_authenticationCredentials;
	
	BOOL _shouldStartTLS;
	
	AFPacketQueue *_transactionQueue;
}

+ (NSString *)userAgent;
+ (void)setUserAgent:(NSString *)userAgent;

@property (retain) CFHTTPAuthenticationRef authentication __attribute__((NSObject));
@property (copy) NSDictionary *authenticationCredentials;

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
	If passed an NSURLRequest with an HTTPBodyStream, an exception is thrown.
 */
- (BOOL)performRequest:(NSURLRequest *)request error:(NSError **)errorRef;

/*!
	@brief
	Replaces NSURLDownload which can't be scheduled in multiple run loops or modes.
	
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
