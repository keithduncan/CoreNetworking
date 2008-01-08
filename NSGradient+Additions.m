//
//  NSGradient+Additions.m
//  Shared Source
//
//  Created by Keith Duncan on 28/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSGradient+Additions.h"

@implementation NSGradient (Additions)

+ (NSGradient *)keySourceListSelectionGradient {
	static NSGradient *keyGradient = nil;
	if (keyGradient == nil) {
		NSColor *topColor = [NSColor colorWithCalibratedRed:(93.0/255.0) green:(148.0/255.0) blue:(214.0/255.0) alpha:1.0];
		NSColor *endColor = [NSColor colorWithCalibratedRed:(25.0/255.0) green:(86.0/255.0) blue:(173.0/255.0) alpha:1.0];
		keyGradient = [[NSGradient alloc] initWithStartingColor:topColor endingColor:endColor];
	}
		
	return keyGradient;
}

+ (NSGradient *)sourceListSelectionGradient {
	static NSGradient *selectionGradient = nil;
	if (selectionGradient == nil) {
		NSColor *topColor = [NSColor colorWithCalibratedRed:(161.0/255.0) green:(176.0/255.0) blue:(207.0/255.0) alpha:1.0];
		NSColor *endColor = [NSColor colorWithCalibratedRed:(113.0/255.0) green:(133.0/255.0) blue:(171.0/255.0) alpha:1.0];
		selectionGradient = [[NSGradient alloc] initWithStartingColor:topColor endingColor:endColor];
	}
	
	return selectionGradient;
}

@end
