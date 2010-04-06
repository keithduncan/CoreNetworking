//
//  NSArray+Additions.h
//  Amber
//
//  Created by Keith Duncan on 27/03/2007.
//  Copyright 2007. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@brief
	This returns whether or not it is safe to use <tt>-objectAtIndex:</tt> for a given index.
 */
NS_INLINE BOOL AFArrayContainsIndex(NSArray *array, NSUInteger index) {
	return NSLocationInRange(index, NSMakeRange(0, [array count]));
}

/*!
	@brief
	This returns nil of the index isn't present in the array.
 */
NS_INLINE id AFSafeObjectAtIndex(NSArray *array, NSUInteger index) {
	return (AFArrayContainsIndex(array, index) ? [array objectAtIndex:index] : nil);
}

@interface NSArray (AFAdditions)

- (NSArray *)arrayByAddingObjectsFromSet:(NSSet *)set;

- (NSArray *)subarrayFromIndex:(NSUInteger)index;

/*!
	@brief
	This returns the only object in the array, or nil if the receiver doesn't contain exactly one object.
 */
- (id)onlyObject;

@end
