//
//  NSTreeNode+Additions.h
//  Amber
//
//  Created by Keith Duncan on 22/08/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*!
	@header
 
	@brief
	These functions should really be a category on NSTreeNode, however because of an implementation detail in NSTreeController it returns an object conforming to the interface of NSTreeNode but not actually decending from it.
	These functions will work for both the private class returned from NSTreeController and your own NSTreeNode based structures.
 
	This has been filed as rdar://problem/5438559 '_NSControllerTreeProxy should inherit from NSTreeNode'
 */

/*!
	@brief
	This returns a collection of nodes by concatenating the leaf of each index path to a set.
 */
extern NSSet *AFTreeNodeObjectsAtIndexPaths(NSTreeNode *self, NSArray *indexPaths);

/*!
	@brief
	Reduce a tree into a flat representation.
 
	@detail
	This function may be faster than <tt>AFTreeNodeArrayFromNodeInclusive</tt> as order is not preserved.
	
	@result
	A set representation of the tree, collapsed into an unordered collection.
 
	@param inclusive
	Whether to include the receiver node in the result.
 */
extern NSSet *AFTreeNodeSetFromNodeInclusive(NSTreeNode *self, BOOL inclusive);

/*!
	@brief
	Reduce a tree into a flat representation.
	
	@result
	A flat representation of the tree, collapsed into an unordered collection.
 
	@param inclusive
	Whether to include the receiver node in the result.
 */
extern NSArray *AFTreeNodeArrayFromNodeInclusive(NSTreeNode *self, BOOL inclusive);

/*!
	@brief
	Recursive tree node enumeration handler. Add the child nodes of the receiver to the provided collection.
 
	@detail
	It handles the creation of an ordered collection by enumerating the children and then adding each of their children in order.
 
	@param collection
	A mutable collection, either NSMutableArray or NSMutableSet or equivalent, otherwise an exception will be thrown.
 */
extern void AFTreeNodeAddChildrenToCollection(NSTreeNode *self, id <NSFastEnumeration> collection);
