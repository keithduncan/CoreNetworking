/*
 *  AFGeometry.m
 *  Amber
 *
 *  Created by Keith Duncan on 04/09/2007.
 *  Copyright 2007 thirty-three. All rights reserved.
 *
 */

#include "AFGeometry.h"

void AFRectDivideEqually(CGRect rect, CGRectEdge edge, NSUInteger count, CGRect *buffer) {
	BOOL vertical = (edge == CGRectMinXEdge || edge == CGRectMaxXEdge);
	CGFloat size = (vertical ? CGRectGetWidth(rect) : CGRectGetHeight(rect))/count;
	
	CGRect remainder;
	CGRectDivide(rect, buffer, &remainder, size, edge);
	
	for (NSUInteger index = 1; index < count; index++)
		buffer[index] = CGRectOffset(buffer[index-1], (vertical * size), (!vertical * size));
}
