//
//  NSBezierPath+Additions.h
//  Amber
//
//  Created by Keith Duncan on 24/06/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum {
	AFCornerLowerLeft	= 1 << 0,
	AFCornerLowerRight	= 1 << 1,
	AFCornerUpperLeft	= 1 << 2,
	AFCornerUpperRight	= 1 << 3,
};
typedef NSUInteger AFCornerOptions;

@interface NSBezierPath (AFAdditions)

/*
	@brief
	This method draws the glyphs of the string argument into a path.
	
	@result
	A path which can be manipulated using <tt>NSAffineTransform</tt>, drawn into views or images.
 */
+ (NSBezierPath *)bezierPathWithString:(NSString *)text inFont:(NSFont *)font;

- (void)appendBezierPathWithString:(NSString *)text inFont:(NSFont *)font;

/*
	@brief
	The corners argument respects the flipped orientation of the current graphics context.
	That is to say that AFCornerLowerRight will always be drawn on the lower right.
 */
+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect corners:(AFCornerOptions)corners radius:(CGFloat)radius;

- (void)appendBezierPathWithRoundedRect:(NSRect)rect corners:(AFCornerOptions)corners radius:(CGFloat)radius;

- (void)applyInnerShadow:(NSShadow *)shadow;

@end

/*
	@brief
	This function draws resolution independent text aligned in the given frame.
	It uses <tt>-[NSBezierPath bexierPathWithString:inFont:]</tt> to generate the path and
	NSAffineTransform to make it fit the frame.
 */
extern void AKDrawStringAlignedInFrame(NSString *text, NSFont *font, NSTextAlignment alignment, NSRect frame);
