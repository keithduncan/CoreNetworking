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
	Parses the parameter list in the <tt>URL</tt> property.
	
	\result
	Returns nil if there are no parameters.
 */
- (NSDictionary *)parametersFromQuery;

/*!
	\brief
	Parses the parameter list in the <tt>HTTPBody</tt> property if the <tt>Content-Type</tt> header is <tt>application/x-www-form-urlencoded</tt>.
	
	\result
	Returns nil if there are no parameters.
 */
- (NSDictionary *)parametersFromBody;

/*!
	\brief
	If non-nil, the file is streamed as the body.
 */
@property (readonly) NSURL *HTTPBodyFile;

@end

@interface NSMutableURLRequest (AFNetworkAdditions)

/*!
	\brief
	Appends the query parameters to <tt>URL</tt> property.
	
	\param parameters
	This value must map <tt>NSString</tt> keys to <tt>NSString</tt> objects.
 */
- (void)appendQueryParameters:(NSDictionary *)parameters;

/*!
	\brief
	If non-nil, the file is streamed as the body.
 */
@property (readwrite, copy) NSURL *HTTPBodyFile;

@end
