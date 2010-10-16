//
//  NSURLRequest+Additions.h
//  AmberFoundation
//
//  Created by Keith Duncan on 04/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*!
	\brief
	
 */
@interface NSMutableURLRequest (AFAdditions)

/*!
	\brief
	Appends the query parameters to <tt>URL</tt> property.
	
	\param parameters
	This value must map <tt>NSString</tt> keys to <tt>NSString</tt> objects.
 */
- (void)appendQueryParameters:(NSDictionary *)parameters;

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

@end
