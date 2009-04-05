//
//  AFSet.m
//  AFCalendarView
//
//  Created by Keith Duncan on 27/03/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "NSArray+Additions.h"

@implementation NSArray (AFAdditions)

- (NSArray *)arrayByAddingObjectsFromSet:(NSSet *)set {
	NSMutableArray *newArray = [[NSMutableArray arrayWithCapacity:([self count] + [set count])] retain];
	
	[newArray addObjectsFromArray:self];
	for (id object in set) [newArray addObject:object];
	
	return newArray;
}

- (NSArray *)subarrayFromIndex:(NSUInteger)index {
	id objects[[self count]];
	[self getObjects:objects];
	
	return [NSArray arrayWithObjects:&objects[index] count:([self count] - index)];
}

- (id)onlyObject {
	return ([self count] == 1) ? AFSafeObjectAtIndex(self, 0) : nil;
}

@end
