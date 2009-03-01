//
//  NSGradient+Additions.m
//  Shared Source
//
//  Created by Keith Duncan on 28/06/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "NSGradient+Additions.h"

@implementation NSGradient (AFAdditions)

+ (NSGradient *)sourceListSelectionGradientIsKey:(BOOL)key {
	if (key) {
		NSColor *topColor = [NSColor colorWithCalibratedRed:(93.0/255.0) green:(148.0/255.0) blue:(214.0/255.0) alpha:1.0];
		NSColor *endColor = [NSColor colorWithCalibratedRed:(25.0/255.0) green:(86.0/255.0) blue:(173.0/255.0) alpha:1.0];
		
		return [[[NSGradient alloc] initWithStartingColor:topColor endingColor:endColor] autorelease];
	} else {
		NSColor *topColor = [NSColor colorWithCalibratedRed:(161.0/255.0) green:(176.0/255.0) blue:(207.0/255.0) alpha:1.0];
		NSColor *endColor = [NSColor colorWithCalibratedRed:(113.0/255.0) green:(133.0/255.0) blue:(171.0/255.0) alpha:1.0];
		
		return [[[NSGradient alloc] initWithStartingColor:topColor endingColor:endColor] autorelease];
	}
	
	return nil;
}

@end
