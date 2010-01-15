//
//  NSTreeNode+Additions.m
//  Amber
//
//  Created by Keith Duncan on 22/08/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "NSTreeNode+Additions.h"

/*
	Private Functions
 */

// Note: this function doesn't handle recursive relationships
static void _AFTreeNodeAddChildrenToCollection(NSTreeNode *self, id <NSFastEnumeration> collection) {
	for (NSTreeNode *currentNode in [self childNodes]) {
		[(id)collection addObject:currentNode];
		
		if ([currentNode isLeaf]) continue;
		_AFTreeNodeAddChildrenToCollection(currentNode, collection);
	}
}

static id <NSFastEnumeration> _AFTreeNodeCollectionFromNode(NSTreeNode *self, Class collectionClass, BOOL inclusive) {
	id collection = [[[collectionClass alloc] init] autorelease];
	
	if (inclusive) [collection addObject:self];
	_AFTreeNodeAddChildrenToCollection(self, collection);
	
	return collection;
}

/*
	Public Functions
 */

NSSet *AFTreeNodeObjectsAtIndexPaths(NSTreeNode *self, NSArray *indexPaths) {
	NSMutableSet *objects = [NSMutableSet setWithCapacity:[indexPaths count]];
	for (NSIndexPath *currentPath in indexPaths) [objects addObject:[self descendantNodeAtIndexPath:currentPath]];
	return objects;
}

NSSet *AFTreeNodeSetFromNodeInclusive(NSTreeNode *self, BOOL inclusive) {
	return (id)_AFTreeNodeCollectionFromNode(self, [NSMutableSet class], inclusive);
}

NSArray *AFTreeNodeArrayFromNodeInclusive(NSTreeNode *self, BOOL inclusive) {
	return (id)_AFTreeNodeCollectionFromNode(self, [NSMutableArray class], inclusive);
}

void AFTreeNodeAddChildrenToCollection(NSTreeNode *self, id <NSFastEnumeration> collection) {
	_AFTreeNodeAddChildrenToCollection(self, collection);
}
