//
//  SourceItem.m
//  Amber
//
//  Created by Keith Duncan on 20/05/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "AFSourceNode.h"

@implementation AFSourceNode

@synthesize name=_name;
@synthesize tag=_type;

- (id)initWithName:(NSString *)name representedObject:(id)representedObject {
	self = [self initWithRepresentedObject:representedObject];
	if (self == nil) return nil;
	
	_name = [name copy];
		
	return self;
}

- (void)dealloc {
	[_name release];
			
	[super dealloc];
}

- (NSImage *)image {
	return nil;
}

- (void)sortWithSortDescriptors:(NSArray *)sortDescriptors recursively:(BOOL)recursively {
	[[self mutableChildNodes] setArray:[[self childNodes] sortedArrayUsingDescriptors:sortDescriptors]];
	if (recursively) for (AFSourceNode *currentNode in [self childNodes]) [currentNode sortWithSortDescriptors:sortDescriptors recursively:recursively];
}

@end
