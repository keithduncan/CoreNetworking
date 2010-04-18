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

/*!
	@brief
	Replaces NSURLConnection for HTTP NSURLRequest objects.
 */
@interface AFHTTPClient : AFHTTPConnection {
 @private
	NSString *_userAgent;
	
	__strong CFHTTPAuthenticationRef _authentication;
	NSDictionary *_authenticationCredentials;
	
	BOOL _shouldStartTLS;
	
	AFPacketQueue *_transactionQueue;
}

+ (NSString *)userAgent;
+ (void)setUserAgent:(NSString *)userAgent;

@property (copy) NSString *userAgent;

@property (retain) CFHTTPAuthenticationRef authentication __attribute__((NSObject));
@property (copy) NSDictionary *authenticationCredentials;

/*
	Transaction Methods
		These automatically enqueue a response, and are for replacing NSURLConnection functionality.
 */

typedef void (^AFHTTPClientTransactionCompletionBlock)(CFHTTPMessageRef response, NSError *error);

/*!
	@brief
	This method enqueues a transaction, which pairs a request with it's response. The request may not be issued immediately.
 */
- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body completionBlock:(AFHTTPClientTransactionCompletionBlock)completionBlock;

/*!
	@brief
	This method enqueues a transaction, which pairs a request with it's response. The request may not be issued immediately.
	This method may assist you in moving to a request/response model from the URL loading architecture in Cocoa.
	
	@detail
	This is likely to be most useful where you already have a web service context, which vends preconstructed requests.
	
	@param request
	This method handles HTTP NSURLRequest objects with an HTTPBodyData, or HTTPBodyFile.
	If passed an NSURLRequest with an HTTPBodyStream, an exception is thrown.
 */
- (void)performRequest:(NSURLRequest *)request completionBlock:(AFHTTPClientTransactionCompletionBlock)completionBlock;

/*!
	@brief
	Replaces NSURLDownload which can't be scheduled in multiple run loops or modes.
	
	@detail
	Will handle large files by streaming them to disk.
 */
- (void)performDownload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation completionBlock:(AFHTTPClientTransactionCompletionBlock)completionBlock;

/*!
	@brief
	Counterpart to <tt>performDownload:onResource:withHeaders:withLocation:</tt>.
	
	@detail
	Will handle large files by streaming them from disk.
 */
- (void)performUpload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation completionBlock:(AFHTTPClientTransactionCompletionBlock)completionBlock;

@end
