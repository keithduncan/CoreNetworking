//
//  AFHTTPConstants.h
//  Amber
//
//  Created by Keith Duncan on 19/07/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif /* TARGET_OS_IPHONE */

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkPacket;
@protocol AFNetworkPacketWriting;

/*
	Schemes
 */

AFNETWORK_EXTERN NSString *const AFNetworkSchemeHTTP;
AFNETWORK_EXTERN NSString *const AFNetworkSchemeHTTPS;

/*
	Message Methods
 */

AFNETWORK_EXTERN NSString *const AFHTTPMethodHEAD;
AFNETWORK_EXTERN NSString *const AFHTTPMethodTRACE;
AFNETWORK_EXTERN NSString *const AFHTTPMethodOPTIONS;

AFNETWORK_EXTERN NSString *const AFHTTPMethodGET;
AFNETWORK_EXTERN NSString *const AFHTTPMethodPOST;
AFNETWORK_EXTERN NSString *const AFHTTPMethodPUT;
AFNETWORK_EXTERN NSString *const AFHTTPMethodDELETE;

/*
	Message Codes
*/

typedef AFNETWORK_ENUM(NSInteger, AFHTTPStatusCode) {
	// 1xx class, informational
	AFHTTPStatusCodeContinue						= 100, /* Continue */
	AFHTTPStatusCodeSwitchingProtocols				= 101, /* Switching Protocols */
	
	// 2xx class, request succeeded
	AFHTTPStatusCodeOK								= 200, /* OK */
	AFHTTPStatusCodeCreated							= 201, /* Created */
	AFHTTPStatusCodePartialContent					= 206, /* Partial Content */
	
	// 3xx class, redirection
	AFHTTPStatusCodeMultipleChoices					= 300, /* Multiple Choices */
	AFHTTPStatusCodeMovedPermanently				= 301, /* Moved Permanently */
	AFHTTPStatusCodeFound							= 302, /* Found */
	AFHTTPStatusCodeSeeOther						= 303, /* See Other */
	AFHTTPStatusCodeNotModified						= 304, /* Not Modified */
	AFHTTPStatusCodeTemporaryRedirect				= 307, /* Temporary Redirect */
	
	// 4xx class, client error
	AFHTTPStatusCodeBadRequest						= 400, /* Bad Request */
	AFHTTPStatusCodeUnauthorized					= 401, /* Unauthorized */
	AFHTTPStatusCodeNotFound						= 404, /* Not Found */
	AFHTTPStatusCodeNotAllowed						= 405, /* Method Not Allowed */
	AFHTTPStatusCodeNotAcceptable					= 406, /* Not Acceptable */
	AFHTTPStatusCodeProxyAuthenticationRequired		= 407, /* Proxy Authentication Required */
	AFHTTPStatusCodeConflict						= 409, /* Conflict */
	AFHTTPStatusCodeUnsupportedMediaType			= 415, /* Unsupported Media Type */
	AFHTTPStatusCodeExpectationFailed				= 417, /* Expectation Failed */
	AFHTTPStatusCodeUpgradeRequired					= 426, /* Upgrade Required */
	
	// 5xx class, server error
	AFHTTPStatusCodeServerError						= 500, /* Server Error */
	AFHTTPStatusCodeNotImplemented					= 501, /* Not Implemented */
};

/*!
	\brief
	Returns a description string for the given code.
	It will throw an exception if passed a code not listed in the `AFHTTPStatusCode` enum.
	
	\details
	This is typed to return a CFStringRef to minimise the impedance mismatch with `CFHTTPMessageCreate()`.
 */
AFNETWORK_EXTERN CFStringRef AFHTTPStatusCodeGetDescription(AFHTTPStatusCode code);

/*
	Message Headers
 */

AFNETWORK_EXTERN NSString *const AFHTTPMessageServerHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageUserAgentHeader;

AFNETWORK_EXTERN NSString *const AFHTTPMessageHostHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageConnectionHeader;

AFNETWORK_EXTERN NSString *const AFHTTPMessageContentLengthHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageContentTypeHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageContentRangeHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageContentMD5Header;

AFNETWORK_EXTERN NSString *const AFHTTPMessageETagHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageIfMatchHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageIfNoneMatchHeader;

AFNETWORK_EXTERN NSString *const AFHTTPMessageTransferEncodingHeader;

AFNETWORK_EXTERN NSString *const AFHTTPMessageAllowHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageAcceptHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageLocationHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageRangeHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageExpectHeader;

AFNETWORK_EXTERN NSString *const AFHTTPMessageWWWAuthenticateHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageAuthorizationHeader;
AFNETWORK_EXTERN NSString *const AFHTTPMessageProxyAuthorizationHeader;

/*
	Message Functions
 */

/*!
	\brief
	Convert an `NSURLRequest` object to a `CFHTTPMessageRef` request.
	
	\details
	If the request uses a stream for the body, an exception is thrown.
 */
AFNETWORK_EXTERN CFHTTPMessageRef AFHTTPMessageCreateForRequest(NSURLRequest *request);

/*!
	\brief
	Convert a `CFHTTPMessageRef` request to an `NSURLRequest` object.
 */
AFNETWORK_EXTERN NSURLRequest *AFHTTPURLRequestForHTTPMessage(CFHTTPMessageRef message);

/*!
	\brief
	Convert an `NSHTTPURLResponse` object to a `CFHTTPMessageRef` response.
	
	\details
	The message will not have a body, since that is captured separately from the `NSHTTPURLResponse` object.
 */
AFNETWORK_EXTERN CFHTTPMessageRef AFHTTPMessageCreateForResponse(NSHTTPURLResponse *response);

/*!
	\brief
	Convert a `CFHTTPMessageRef` response to an `NSHTTPURLResponse` object.
 */
AFNETWORK_EXTERN NSHTTPURLResponse *AFHTTPURLResponseForHTTPMessage(NSURL *URL, CFHTTPMessageRef message);

/*
 
 */

/*!
	\brief
	Response convenience constructor
 */
extern CFHTTPMessageRef AFHTTPMessageMakeResponseWithCode(AFHTTPStatusCode responseCode);

/*!
	\brief
	Packetises a message.
 */
AFNETWORK_EXTERN AFNetworkPacket <AFNetworkPacketWriting> *AFHTTPConnectionPacketForMessage(CFHTTPMessageRef message);

/*
 
 */

/*!
	\brief
	Generate an agent string suitable for the Server or User-Agent headers.
 */
AFNETWORK_EXTERN NSString *AFHTTPAgentStringForBundle(NSBundle *bundle);

/*!
	\brief
	Generate an agent string suitable for the Server or User-Agent headers, for the main bundle.
 */
AFNETWORK_EXTERN NSString *AFHTTPAgentString(void);
