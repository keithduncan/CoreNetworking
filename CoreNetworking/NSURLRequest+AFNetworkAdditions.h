//
//  NSURLRequest+AFNetworkAdditions.h
//  Amber
//
//  Created by Keith Duncan on 14/04/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLRequest (AFNetworkAdditions)

/*!
	\brief
	Parses the parameter list in the `URL` property.
	
	\result
	Returns nil if there are no parameters.
 */
- (NSDictionary *)parametersFromQuery;

/*!
	\brief
	Parses the parameter list in the `HTTPBody` property if the `Content-Type` header is `application/x-www-form-urlencoded`.
	
	\result
	Returns nil if there are no parameters.
 */
- (NSDictionary *)parametersFromBody;

/*!
	\brief
	If non-nil, the file is streamed as the body.
 */
@property (readonly, nonatomic) NSURL *HTTPBodyFile;

@end

@interface NSMutableURLRequest (AFNetworkAdditions)

/*!
	\brief
	Appends the query parameters to `URL` property.
	
	\param parameters
	This value must map `NSString` keys to `NSString` objects.
 */
- (void)appendQueryParameters:(NSDictionary *)parameters;

/*!
	\brief
	If non-nil, the file is streamed as the body.
 */
@property (readwrite, copy, nonatomic) NSURL *HTTPBodyFile;

@end
