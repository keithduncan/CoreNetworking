//
//  NSBezierPath+Additions.m
//  Amber
//
//  Created by Keith Duncan on 24/06/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

//  -applyInnerShadow: created by Sean Patrick O'Brien
//  Copyright 2008 MolokoCacao. All rights reserved.

#import "NSBezierPath+Additions.h"

#import "AFGeometry.h"

@implementation NSBezierPath (AFAdditions)

+ (NSBezierPath *)bezierPathWithString:(NSString *)text inFont:(NSFont *)font {
	NSBezierPath *textPath = [self bezierPath];
	[textPath appendBezierPathWithString:text inFont:font];
	return textPath;
}

- (void)appendBezierPathWithString:(NSString *)text inFont:(NSFont *)font {
	if ([self isEmpty]) [self moveToPoint:NSZeroPoint];
	
	NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:text];
	CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)attributedString);
	[attributedString release];
	
	CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
	CFIndex count = CFArrayGetCount(glyphRuns);
	
	for (CFIndex index = 0; index < count; index++) {
		CTRunRef currentRun = CFArrayGetValueAtIndex(glyphRuns, index);
		
		CFIndex glyphCount = CTRunGetGlyphCount(currentRun);
		
		CGGlyph glyphs[glyphCount];
		CTRunGetGlyphs(currentRun, CTRunGetStringRange(currentRun), glyphs);
		
		NSGlyph bezierPathGlyphs[glyphCount];
		for (CFIndex glyphIndex = 0; glyphIndex < glyphCount; glyphIndex++)
			bezierPathGlyphs[glyphIndex] = glyphs[glyphIndex];
		
		[self appendBezierPathWithGlyphs:bezierPathGlyphs count:glyphCount inFont:font];
	}
	
	CFRelease(line);
}

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect corners:(AFRoundedCornerOptions)corners radius:(CGFloat)radius {
	NSBezierPath *path = [self bezierPath];
	[path appendBezierPathWithRoundedRect:rect corners:corners radius:radius];
	return path;
}

- (void)appendBezierPathWithRoundedRect:(NSRect)rect corners:(AFRoundedCornerOptions)corners radius:(CGFloat)radius {
	BOOL flipped = [[NSGraphicsContext currentContext] isFlipped];
	
	if (flipped) {
		NSUInteger upperCorners = (corners & (AFUpperLeftCorner | AFUpperRightCorner));
		
		corners = corners << 2;
		corners |= (upperCorners >> 2);
		
		corners &= (AFUpperLeftCorner | AFUpperRightCorner | AFLowerLeftCorner | AFLowerRightCorner);
	}
	
	[self moveToPoint:NSMakePoint(NSMidX(rect), NSMinY(rect))];
	
	radius = MIN(radius, MIN(NSWidth(rect), NSHeight(rect))/2.0);
	
	if (corners & AFLowerRightCorner)
		[self appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect)) toPoint:NSMakePoint(NSMaxX(rect), NSMidY(rect)) radius:radius];
	else {
		[self lineToPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect))];
		[self lineToPoint:NSMakePoint(NSMaxX(rect), NSMidY(rect))];
	}
	
	if (corners & AFUpperRightCorner)
		[self appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect)) toPoint:NSMakePoint(NSMidX(rect), NSMaxY(rect)) radius:radius];
	else {
		[self lineToPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
		[self lineToPoint:NSMakePoint(NSMidX(rect), NSMaxY(rect))];
	}
	
	if (corners & AFUpperLeftCorner)
		[self appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect)) toPoint:NSMakePoint(NSMinX(rect), NSMidY(rect)) radius:radius];
	else {
		[self lineToPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect))];
		[self lineToPoint:NSMakePoint(NSMinX(rect), NSMidY(rect))];
	}
	
	if (corners & AFLowerLeftCorner)
		[self appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(rect), NSMinY(rect)) toPoint:NSMakePoint(NSMidX(rect), NSMinY(rect)) radius:radius];
	else 
		[self lineToPoint:NSMakePoint(NSMinX(rect), NSMinY(rect))];
}

- (void)applyInnerShadow:(NSShadow *)shadow {
	[NSGraphicsContext saveGraphicsState];
	
	NSShadow *shadowCopy = [shadow copy];
	
	NSSize offset = shadowCopy.shadowOffset;
	CGFloat radius = shadowCopy.shadowBlurRadius;
	
	NSRect bounds = NSInsetRect(self.bounds, -(ABS(offset.width) + radius), -(ABS(offset.height) + radius));
	
	offset.height += bounds.size.height;
	shadowCopy.shadowOffset = offset;
	
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy:0 yBy:([[NSGraphicsContext currentContext] isFlipped] ? 1 : -1) * bounds.size.height];
	
	NSBezierPath *drawingPath = [NSBezierPath bezierPathWithRect:bounds];
	[drawingPath setWindingRule:NSEvenOddWindingRule];
	
	[drawingPath appendBezierPath:self];
	[drawingPath transformUsingAffineTransform:transform];
	
	[self addClip];
	[shadowCopy set];
	
	[[NSColor blackColor] set];
	[drawingPath fill];
	
	[shadowCopy release];
	
	[NSGraphicsContext restoreGraphicsState];
}

@end

extern void AKDrawStringAlignedInFrame(NSString *text, NSFont *font, NSTextAlignment alignment, NSRect frame) {
	NSCParameterAssert(font != nil);
	
	NSBezierPath *textPath = [NSBezierPath bezierPathWithString:text inFont:font];
	NSRect textPathBounds = NSMakeRect(NSMinX([textPath bounds]), [font descender], NSWidth([textPath bounds]), [font ascender] - [font descender]);
	
	NSAffineTransform *scale = [NSAffineTransform transform];
	CGFloat xScale = NSWidth(frame)/NSWidth(textPathBounds);
	CGFloat yScale = NSHeight(frame)/NSHeight(textPathBounds);
	[scale scaleBy:MIN(xScale, yScale)];
	[textPath transformUsingAffineTransform:scale];
	
	textPathBounds.origin = [scale transformPoint:textPathBounds.origin];
	textPathBounds.size = [scale transformSize:textPathBounds.size];
	
	NSAffineTransform *originCorrection = [NSAffineTransform transform];
	NSPoint centeredOrigin = AFRectCenteredSize(frame, textPathBounds.size).origin;
	[originCorrection translateXBy:(centeredOrigin.x - NSMinX(textPathBounds)) yBy:(centeredOrigin.y - NSMinY(textPathBounds))];
	[textPath transformUsingAffineTransform:originCorrection];
	
	if (alignment != NSJustifiedTextAlignment && alignment != NSCenterTextAlignment) {
		NSAffineTransform *alignmentTransform = [NSAffineTransform transform];
		
		CGFloat deltaX = 0;
		if (alignment == NSLeftTextAlignment) deltaX = -(NSMinX([textPath bounds]) - NSMinX(frame));
		else if (alignment == NSRightTextAlignment) deltaX = (NSMaxX(frame) - NSMaxX([textPath bounds]));
		[alignmentTransform translateXBy:deltaX yBy:0];
		
		[textPath transformUsingAffineTransform:alignmentTransform];
	}
	
	[textPath fill];
}
