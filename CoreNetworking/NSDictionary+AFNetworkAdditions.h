//
//  NSDictionary+AFNetworkAdditions.h
//  CoreNetworking
//
//  Created by Keith Duncan on 17/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSDictionary (AFNetworkAdditions)

/*!
	\brief
	Parse a string for key value pairs using the separator and delimeters given.
	
	\param separator
	The '=' in key=value
	
	\param delimiter
	The '&' in key1=value1&key2=value2
	
	\details
	If a pair has no value, <tt>[NSNull null]</tt> is used.
 */
+ (id)dictionaryWithString:(NSString *)string separator:(NSString *)separator delimiter:(NSString *)delimiter;

/*!
	\brief
	For HTTP message header, and MIME header parameter lookup.
 */
- (id)objectForCaseInsensitiveKey:(NSString *)key;

@end
