//
//  NSGradient+Additions.h
//  Amber
//
//  Created by Keith Duncan on 28/06/2007.
//  Copyright 2007. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSGradient (AFAdditions)

/*!
	@result
	The source list gradient, this should be drawn at +90 degrees.
 */
+ (NSGradient *)sourceListSelectionGradient:(BOOL)isKey;

@end
