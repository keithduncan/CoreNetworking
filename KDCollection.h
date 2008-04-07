//
//  KDSet.h
//  KDCalendarView
//
//  Created by Keith Duncan on 27/03/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_INLINE BOOL KDArrayContainsIndex(NSArray *array, NSUInteger index) {
	return NSLocationInRange(index, (NSRange){0, [array count]});
}

NS_INLINE id KDSafeObjectAtIndex(NSArray *array, NSUInteger index) {
	return (KDArrayContainsIndex(array, index) ? [array objectAtIndex:index] : nil);
}

@interface NSSet (Additions)
- (NSSet *)setByAddingObjects:(id)firstObject, ... NS_REQUIRES_NIL_TERMINATION;
@end

@interface NSArray (Additions)
- (NSArray *)arrayByAddingObjectsFromSet:(NSSet *)set;

- (NSArray *)subarrayFromIndex:(NSUInteger)index;
@end

@interface NSDictionary (Additions)
- (NSDictionary *)diff:(id)dictionary;
@end
