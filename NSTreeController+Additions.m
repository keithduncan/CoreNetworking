//  NSTreeController-DMExtensions.m
//  Library
//
//  Created by William Shipley on 3/10/06.
//  Copyright 2006 Delicious Monster Software, LLC. Some rights reserved,
//    see Creative Commons license on wilshipley.com

#import "NSTreeController+Additions.h"

@interface NSTreeController (AFPrivateAdditions)
- (NSIndexPath *)_indexPathToObject:(id)object inTree:(NSTreeNode *)tree;
@end

@implementation NSTreeController (AFAdditions)

- (void)setSelectedObjects:(NSArray *)newSelectedObjects {
	NSMutableArray *indexPaths = [NSMutableArray array];
	for (id currentObject in newSelectedObjects) {
		NSIndexPath *currentIndexPath = [self _indexPathToObject:currentObject inTree:[self arrangedObjects]];
		if (currentIndexPath != nil) [indexPaths addObject:currentIndexPath];
	}
	
	[self setSelectionIndexPaths:indexPaths];
}

- (NSIndexPath *)indexPathToObject:(id)object {
	return [self _indexPathToObject:object inTree:[self arrangedObjects]];
}

@end

@implementation NSTreeController (AFPrivateAdditions)

- (NSIndexPath *)_indexPathToObject:(id)object inTree:(NSTreeNode *)node {
	for (NSTreeNode *currentNode in [node childNodes]) {
		if ([currentNode representedObject] == object) return [currentNode indexPath];
		
		NSIndexPath *indexPath = [self _indexPathToObject:object inTree:currentNode];
		if (indexPath != nil) return indexPath;
	}
	
	return nil;
}

@end
