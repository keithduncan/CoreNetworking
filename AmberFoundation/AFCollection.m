//
//  AFSet.m
//  AFCalendarView
//
//  Created by Keith Duncan on 27/03/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "AFCollection.h"

@implementation NSSet (AFAdditions)

- (NSSet *)setByAddingObjects:(id)currentObject, ... {
	va_list objectList;
	NSMutableSet *newSet = [[self mutableCopy] autorelease];
	
	if (currentObject != nil) {
		[newSet addObject:currentObject];
		
		va_start(objectList, currentObject);
		
		while (currentObject = va_arg(objectList, id))
			[newSet addObject:currentObject];
		
		va_end(objectList);
	}
	
	return [newSet copy];
}

@end

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

@implementation NSDictionary (AFAdditions)

- (NSDictionary *)diff:(id)dictionary {
	NSMutableDictionary *difference = [NSMutableDictionary dictionary];
	
	for (id currentKey in self) {		
		if (![[self objectForKey:currentKey] isEqual:[dictionary valueForKey:currentKey]])
			[difference setObject:[dictionary valueForKey:currentKey] forKey:currentKey];
	}
	
	return difference;
}

@end
