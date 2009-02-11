//
//  AFErrorCell.m
//  iLog fitness
//
//  Created by Keith Duncan on 21/06/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "AFErrorCell.h"

#import "AFError.h"

@implementation AFErrorCell

// objectValue should be a AFError object
- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	AFError *error = [self objectValue];
	
	if (![error isKindOfClass:[AFError class]]) [NSException raise:NSInternalInconsistencyException format:@"-[AFErrorCell drawWithFrame:inView:], the object value is not a AFError object - cannot draw it!"];

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
