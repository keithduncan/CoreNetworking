//
//  NSDate+Additions.h
//  Amber
//
//  Created by Keith Duncan on 03/12/2006.
//  Copyleft 2006. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\file
 */

@interface NSDateComponents (AFAdditions)

/*!
	\brief
	Checks each of the components in |flags| for equality against |components|.
 */
- (BOOL)components:(NSUInteger)flags match:(NSDateComponents *)components;

@end
