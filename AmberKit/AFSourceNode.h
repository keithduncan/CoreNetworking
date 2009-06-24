//
//  SourceItem.h
//  Amber
//
//  Created by Keith Duncan on 20/05/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*
	@brief
	A node subclass suitable for source list structures.
 */
@interface AFSourceNode : NSTreeNode {
 @private
	NSString *_name;	
	NSUInteger _type;
}

/*!
	@brief
	Designated Initializer.
 */
- (id)initWithName:(NSString *)name representedObject:(id)representedObject;

/*!
	@brief
	This property will likely be displayed in a sidebar.
 */
@property (copy) NSString *name;

/*!
	@brief
	This property allows you to provide a means to quickly identify the type of the node.
 */
@property (assign) NSUInteger tag;

/*
	@brief
	NSTreeNode is an AppKit class so the image representation can be presentation-layer specific.
 */
@property (readonly) NSImage *image;

@end
