//
//  NSDictionary+Additions.h
//  Amber
//
//  Created by Keith Duncan on 05/04/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (AFAdditions)

/*!
	\brief
	Enumerates the receiver and returns a dictionary of key-value pairs for each key where the object for key isn't equal to the |container|'s <tt>-valueForKey:</tt>.
 */
- (NSDictionary *)diff:(id)container;

/*!
	\brief
	For HTTP message header lookup.
 */
- (id)objectForCaseInsensitiveKey:(NSString *)key;

@end
