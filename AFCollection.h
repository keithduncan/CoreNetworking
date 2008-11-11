//
//  AFSet.h
//  AFCalendarView
//
//  Created by Keith Duncan on 27/03/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_INLINE BOOL AFArrayContainsIndex(NSArray *array, NSUInteger index) {
	return NSLocationInRange(index, (NSRange){0, [array count]});
}

NS_INLINE id AFSafeObjectAtIndex(NSArray *array, NSUInteger index) {
	return (AFArrayContainsIndex(array, index) ? [array objectAtIndex:index] : nil);
}

@interface NSSet (AFAdditions)
// This returns a copy of the original with the additional objects appended to the collection
- (NSSet *)setByAddingObjects:(id)firstObject, ... NS_REQUIRES_NIL_TERMINATION;
@end

@interface NSArray (AFAdditions)
- (NSArray *)arrayByAddingObjectsFromSet:(NSSet *)set;

- (NSArray *)subarrayFromIndex:(NSUInteger)index;
@end

@interface NSDictionary (AFAdditions)
- (NSDictionary *)diff:(id)dictionary;
@end
