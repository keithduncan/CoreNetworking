//
//  KDErrorCell.m
//  iLog fitness
//
//  Created by Keith Duncan on 21/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "KDErrorCell.h"

#import "KDError.h"

@implementation KDErrorCell

// objectValue should be a KDError object
- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	KDError *error = [self objectValue];
	
	if (![error isKindOfClass:[KDError class]]) [NSException raise:NSInternalInconsistencyException format:@"-[KDErrorCell drawWithFrame:inView:], the object value is not a KDError object - cannot draw it!"];

	NSRect titleRect, descriptionRect;
	NSDivideRect(frame, &titleRect, &descriptionRect, NSHeight(frame) / 2.0, NSMinYEdge);
	
	[self setObjectValue:error.name];
	[self setTextColor:[NSColor blackColor]];
	[super drawInteriorWithFrame:titleRect inView:view];
	
	[self setObjectValue:error.reason];
	[self setTextColor:[NSColor darkGrayColor]];
	[super drawInteriorWithFrame:descriptionRect inView:view];
	
	[self setObjectValue:error];
}

@end
