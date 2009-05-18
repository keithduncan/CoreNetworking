//
//  NSTreeNode+Additions.h
//  Amber
//
//  Created by Keith Duncan on 22/08/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*
	@header
 
	@brief
	These functions should really be a category on NSTreeNode, however because of an implementation
	detail in NSTreeController it returns an object conforming to the interface of NSTreeNode but
	not actually decending from it. These functions will work for both the private class returned from
	NSTreeController and your own NSTreeNode based structures.
 */

/*
	This returns a collection of nodes by concatenating the leaf of each index path to a set.
 */
extern NSSet *AFTreeNodeObjectsAtIndexPaths(NSTreeNode *self, NSArray *indexPaths);

/*
	This returns a set representation of the tree collapsed into an unordered collection.
	This function may be faster for larege data sets where order is not important.
	@param	|inclusive| determines whether to include the |self| node in the result.
 */
extern NSSet *AFTreeNodeSetFromNodeInclusive(NSTreeNode *self, BOOL inclusive);

/*
	This returns a set representation of the tree collapsed into an unordered collection.
	@param	|inclusive| determines whether to include the |self| node in the result.
 */
extern NSArray *AFTreeNodeArrayFromNodeInclusive(NSTreeNode *self, BOOL inclusive);

/*
	This is a recursive function that will add the child nodes of |self| to the provided collection.
	It accounts for creating an ordered collection by enumerating the children and then adding each of thier children in order.
	@param	|collection| should be a mutable collection, otherwise an exception will be thrown.
 */
extern void AFTreeNodeAddChildrenToCollection(NSTreeNode *self, id <NSFastEnumeration> collection);
