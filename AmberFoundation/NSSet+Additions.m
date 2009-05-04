//
//  NSSet+Additions.m
//  Amber
//
//  Created by Keith Duncan on 05/04/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "NSSet+Additions.h"

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
	
	return newSet;
}

@end
