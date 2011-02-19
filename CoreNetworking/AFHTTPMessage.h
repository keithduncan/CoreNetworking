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
#endif

@class AFNetworkPacket;
@protocol AFNetworkPacketWriting;

/*
	Message Functions
 */

/*!
	\brief
	Convert an <tt>NSURLRequest</tt> object to a <tt>CFHTTPMessageRef</tt> request.
	
	\details
	If the request uses a stream for the body, an exception is thrown.
 */
extern CFHTTPMessageRef AFHTTPMessageCreateForRequest(NSURLRequest *request);

/*!
	\brief
	Convert a <tt>CFHTTPMessageRef</tt> request to an <tt>NSURLRequest</tt> object.
 */
extern NSURLRequest *AFHTTPURLRequestForHTTPMessage(CFHTTPMessageRef message);

/*!
	\brief
	Convert an <tt>NSHTTPURLResponse</tt> object to a <tt>CFHTTPMessageRef</tt> response.
	
	\details
	The message will not have a body, since that is captured separately from the <tt>NSHTTPURLResponse</tt> object.
 */
extern CFHTTPMessageRef AFHTTPMessageCreateForResponse(NSHTTPURLResponse *response);

/*!
	\brief
	Convert a <tt>CFHTTPMessageRef</tt> response to an <tt>NSHTTPURLResponse</tt> object.
 */
extern NSHTTPURLResponse *AFHTTPURLResponseForHTTPMessage(NSURL *URL, CFHTTPMessageRef message);

/*!
	\brief
	Packetises a message.
 */
extern AFNetworkPacket <AFNetworkPacketWriting> *AFHTTPConnectionPacketForMessage(CFHTTPMessageRef message);

/*
	HTTP methods
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

extern NSString *const AFHTTPMessageServerHeader;
extern NSString *const AFHTTPMessageUserAgentHeader;

extern NSString *const AFHTTPMessageHostHeader;
extern NSString *const AFHTTPMessageConnectionHeader;

extern NSString *const AFHTTPMessageContentLengthHeader;
extern NSString *const AFHTTPMessageContentTypeHeader;
extern NSString *const AFHTTPMessageContentRangeHeader;
extern NSString *const AFHTTPMessageContentMD5Header;

extern NSString *const AFHTTPMessageETagHeader;
extern NSString *const AFHTTPMessageIfNoneMatchHeader;

extern NSString *const AFHTTPMessageTransferEncodingHeader;

extern NSString *const AFHTTPMessageAllowHeader;
extern NSString *const AFHTTPMessageLocationHeader;
extern NSString *const AFHTTPMessageRangeHeader;
extern NSString *const AFHTTPMessageExpectHeader;

extern NSString *const AFHTTPMessageWWWAuthenticateHeader;
extern NSString *const AFHTTPMessageAuthorizationHeader;
extern NSString *const AFHTTPMessageProxyAuthorizationHeader;

/*
	AFHTTPConnection Message Codes
*/

enum {
	// 1xx class, informational
	AFHTTPStatusCodeContinue						= 100, /* Continue */
	AFHTTPStatusCodeSwitchingProtocols				= 101, /* Switching Protocols */
	
	// 2xx class, request succeeded
	AFHTTPStatusCodeOK								= 200, /* OK */
	AFHTTPStatusCodePartialContent					= 206, /* Partial Content */
	
	// 3xx class, redirection
	AFHTTPStatusCodeFound							= 302, /* Found */
	AFHTTPStatusCodeSeeOther						= 303, /* See Other */
	AFHTTPStatusCodeNotModified						= 304, /* Not Modified */
	
	// 4xx class, client error
	AFHTTPStatusCodeBadRequest						= 400, /* Bad Request */
	AFHTTPStatusCodeUnauthorized					= 401, /* Unauthorized */
	AFHTTPStatusCodeNotFound						= 404, /* Not Found */
	AFHTTPStatusCodeNotAllowed						= 405, /* Not Allowed */
	AFHTTPStatusCodeProxyAuthenticationRequired		= 407, /* Proxy Authentication Required */
	AFHTTPStatusCodeUpgradeRequired					= 426, /* Upgrade Required */
	
	// 5xx class, server error
	AFHTTPStatusCodeServerError						= 500, /* Server Error */
	AFHTTPStatusCodeNotImplemented					= 501, /* Not Implemented */
};
typedef NSInteger AFHTTPStatusCode;

/*!
	\brief
	Returns a description string for the given code.
	It will throw an exception if passed a code not listed in the <tt>AFHTTPStatusCode<tt> enum.
	
	\details
	This is typed to return a CFStringRef to minimise the impedance mismatch with <tt>CFHTTPMessageCreate()</tt>.
 */
extern CFStringRef AFHTTPStatusCodeGetDescription(AFHTTPStatusCode code);

/*!
	\brief
	Generate an agent string suitable for the Server or User-Agent headers.
 */
extern NSString *AFHTTPAgentStringForBundle(NSBundle *bundle);

/*!
	\brief
	Generate an agent string suitable for the Server or User-Agent headers, for the main bundle.
 */
extern NSString *AFHTTPAgentString(void);
