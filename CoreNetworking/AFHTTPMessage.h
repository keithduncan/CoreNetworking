//
//  AFHTTPConstants.h
//  Amber
//
//  Created by Keith Duncan on 19/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

/*
	Message Functions
 */

/*!
	@brief
	Converts from an NSURLRequest to a CFHTTPMessage request.
 
	@detail
	If the request parameter uses a stream for the body, this function will throw an exception.
 */
extern CFHTTPMessageRef AFHTTPMessageForRequest(NSURLRequest *request);

/*!
	@brief
	Converts from a CFHTTPMessage request to an NSURLRequest.
 */
extern NSURLRequest *AFURLRequestForHTTPMessage(CFHTTPMessageRef message);

/*
	HTTP verbs
 */

extern NSString *const AFHTTPMethodHEAD;
extern NSString *const AFHTTPMethodTRACE;
extern NSString *const AFHTTPMethodOPTIONS;

extern NSString *const AFHTTPMethodGET;
extern NSString *const AFHTTPMethodPOST;
extern NSString *const AFHTTPMethodPUT;
extern NSString *const AFHTTPMethodDELETE;

/*
	AFHTTPConnection Schemes
 */

extern NSString *const AFNetworkSchemeHTTP;
extern NSString *const AFNetworkSchemeHTTPS;

/*
	AFHTTPConnection Message Headers
 */

extern NSString *const AFHTTPMessageUserAgentHeader;
extern NSString *const AFHTTPMessageContentLengthHeader;
extern NSString *const AFHTTPMessageHostHeader;
extern NSString *const AFHTTPMessageConnectionHeader;
extern NSString *const AFHTTPMessageContentTypeHeader;
extern NSString *const AFHTTPMessageAllowHeader;

/*
	AFHTTPConnection Message Codes
*/

enum {
	// 2xx class codes indicate the request succeeded
	AFHTTPStatusCodeOK = 200, /* OK */
	AFHTTPStatusCodePartialContent = 206, /* Partial Content */
	
	// 4xx class codes indicate a client error
	AFHTTPStatusCodeBadRequest = 400, /* Bad Request */
	AFHTTPStatusCodeNotFound = 404, /* Not Found */
	AFHTTPStatusCodeNotAllowed = 405, /* Not Allowed */
	AFHTTPStatusCodeUpgradeRequired = 426, /*  Upgrade Required */
	
	// 5xx class codes indicate a server error
	AFHTTPStatusCodeServerError = 500, /* Server Error */
	AFHTTPStatusCodeNotImplemented = 501, /* Not Implemented */
};
typedef NSInteger AFHTTPStatusCode;

/*!
	@brief
	This returns a description string for a given code.
	It will throw an exception if passed a code not listed in the AFHTTPStatusCode enumeration.
	
	@detail
	This is typed to return a CFStringRef to minimise the impedance mismatch with CFHTTPMessageCreate.
 */
extern CFStringRef AFHTTPStatusCodeDescription(AFHTTPStatusCode code);
