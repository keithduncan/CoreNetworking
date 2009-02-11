/*
 *  AFGeometry.m
 *  Shared Source
 *
 *  Created by Keith Duncan on 04/09/2007.
 *  Copyright 2007 thirty-three. All rights reserved.
 *
 */

#include "AFGeometry.h"

#if (TARGET_OS_MAC && !(TARGET_OS_IPHONE))

void AFDivideRect(NSRect rect, NSRectEdge edge, NSUInteger count, NSRectArray buffer) {
	BOOL vertical = (edge == NSMinXEdge || edge == NSMaxXEdge);
	CGFloat size = (vertical ? NSHeight(rect) : NSWidth(rect))/count;
	
	NSRect remainder;
	NSDivideRect(rect, buffer, &remainder, size, edge);
	
	for (NSUInteger index = 1; index < count; index++) 
		buffer[index] = NSOffsetRect(buffer[index-1], (!vertical ? size : 0), (vertical ? size : 0));
}

#endif
