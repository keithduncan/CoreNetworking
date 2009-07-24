//
//  AFHTTPConstants.h
//  Amber
//
//  Created by Keith Duncan on 19/07/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

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
