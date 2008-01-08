//
//  KDSet.m
//  KDCalendarView
//
//  Created by Keith Duncan on 27/03/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "KDCollection.h"

@implementation NSSet (Additions)

- (NSSet *)setByAddingObjects:(id)currentObject, ... {
	va_list objectList;
	NSMutableSet *newSet = [[NSMutableSet setWithSet:self] retain];
	
	if (currentObject != nil) {
		[newSet addObject:currentObject];
		
		va_start(objectList, currentObject);
		while (currentObject = va_arg(objectList, id))
			[newSet addObject:currentObject];
		
		va_end(objectList);
	}
	
	return newSet;
}

@end

@implementation NSArray (Additions)

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

@end

@implementation NSDictionary (Additions)

- (NSDictionary *)diff:(NSDictionary *)dictionary {
	NSMutableDictionary *difference = [NSMutableDictionary dictionary];
	
	for (id currentKey in dictionary)
		if (![[self allKeys] containsObject:currentKey] || ![[self objectForKey:currentKey] isEqual:[dictionary objectForKey:currentKey]]) 
			[difference setObject:[dictionary objectForKey:currentKey] forKey:currentKey];
	
	return difference;
}

- (NSDictionary *)applyDifference:(NSDictionary *)diff {
	NSMutableDictionary *mutableSelf = [[self mutableCopy] autorelease];
	for (id currentKey in diff) [mutableSelf setObject:[diff objectForKey:currentKey] forKey:currentKey];
	return mutableSelf;
}

@end
