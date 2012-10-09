//
//  AFHTTPMessageAccept.h
//  CoreNetworking
//
//  Created by Keith Duncan on 07/10/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFHTTPMessageMediaType;
@class AFHTTPMessageAcceptType;

/*!
	\brief
	Common model for the Content-Type value and Accept values
 */
@interface AFHTTPMessageMediaType : NSObject

extern NSString *const AFHTTPMessageMediaTypeTypeKey;
@property (readonly, copy, nonatomic) NSString *type;

extern NSString *const AFHTTPMessageMediaTypeParametersKey;
@property (readonly, copy, nonatomic) NSDictionary *parameters;

@end

/*!
	\brief
	Accept parameters will include the q value if present, parameters will include all parameters up to the q parameter if present or all parameters if absent.
 */
@interface AFHTTPMessageAcceptType : AFHTTPMessageMediaType

extern NSString *const AFHTTPMessageAcceptAcceptParametersKey;
@property (readonly, copy, nonatomic) NSDictionary *acceptParameters;

@end

/*!
	\brief
	Parse a Content-Type header into a type
 */
AFNETWORK_EXTERN AFHTTPMessageMediaType *AFHTTPMessageParseContentTypeHeader(NSString *contentTypeHeader);

/*!
	\brief
	Parse non empty accept header values and their parameters.
	
	\return
	NSArray of AFHTTPMessageAcceptType objects
 */
AFNETWORK_EXTERN NSArray *AFHTTPMessageParseAcceptHeader(NSString *acceptHeader);

/*!
	\brief
	The client provided accept header values aren't ordered by their position in the header, they're ordered by quality value, there is an implicit quality of 1 if the q parameter is absent and types with a q value of 0 must not be sent, clients can also accept content types with wildcards.
	
	\details
	Order the accept values by canonical priority and pick the first matching content type that can be provided.
	
	\return
	One of the objects passed in `preferredContentTypes` or nil
	If nil is returned it would be appropriate to return a "406 Not Acceptable" response
 */
AFNETWORK_EXTERN NSString *AFHTTPMessageChooseContentTypeForAcceptTypes(NSArray *accepts, NSArray *serverContentTypePreference);
