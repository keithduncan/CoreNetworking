//
//  NSBezierPath+Additions.m
//  KDStringView
//
//  Created by Keith Duncan on 24/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSBezierPath+Additions.h"

#import "KDGeometry.h"

@implementation NSBezierPath (Additions)

+ (NSBezierPath *)bezierPathWithString:(NSString *)text inFont:(NSFont *)font {
	NSBezierPath *textPath = [self bezierPath];
	[textPath moveToPoint:NSZeroPoint];
	[textPath appendBezierPathWithString:text inFont:font];
	return textPath;
}

+ (NSBezierPath *)bezierPathWithString:(NSString *)text inFont:(NSFont *)font aligned:(NSTextAlignment)alignment inFrame:(NSRect)frame {
	NSBezierPath *textPath = [self bezierPathWithString:text inFont:font];
	NSRect textPathBounds = (NSRect){NSMinX([textPath bounds]), [font descender], NSWidth([textPath bounds]), [font ascender] - [font descender]};
	
	NSAffineTransform *scale = [NSAffineTransform transform];
	CGFloat xScale = NSWidth(frame) / NSWidth(textPathBounds);
	CGFloat yScale = NSHeight(frame) / NSHeight(textPathBounds);
	[scale scaleBy:MIN(xScale, yScale)];
	[textPath transformUsingAffineTransform:scale];
	
	textPathBounds.origin = [scale transformPoint:textPathBounds.origin];
	textPathBounds.size = [scale transformSize:textPathBounds.size];
	
	NSAffineTransform *originCorrection = [NSAffineTransform transform];
	NSPoint centeredOrigin = SizeCenteredInRect(textPathBounds.size, frame).origin;
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
	
	return textPath;
}

- (void)appendBezierPathWithString:(NSString *)text inFont:(NSFont *)font {
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

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect corners:(KDRoundedCornerOptions)corners radius:(CGFloat)radius {
	NSBezierPath *path = [self bezierPath];
	[path moveToPoint:NSMakePoint(NSMidX(rect), NSMinY(rect))];
	
	radius = MIN(radius, MIN(NSWidth(rect), NSHeight(rect))/2.0);
	
	if (corners & KDLowerRightCorner)
		[path appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect)) toPoint:NSMakePoint(NSMaxX(rect), NSMidY(rect)) radius:radius];
	else {
		[path lineToPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect))];
		[path lineToPoint:NSMakePoint(NSMaxX(rect), NSMidY(rect))];
	}
	
	if (corners & KDUpperRightCorner)
		[path appendBezierPathWithArcFromPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect)) toPoint:NSMakePoint(NSMidX(rect), NSMaxY(rect)) radius:radius];
	else {
		[path lineToPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
		[path lineToPoint:NSMakePoint(NSMidX(rect), NSMaxY(rect))];
	}
	
	if (corners & KDUpperLeftCorner)
		[path appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect)) toPoint:NSMakePoint(NSMinX(rect), NSMidY(rect)) radius:radius];
	else {
		[path lineToPoint:NSMakePoint(NSMinX(rect), NSMaxY(rect))];
		[path lineToPoint:NSMakePoint(NSMinX(rect), NSMidY(rect))];
	}
	
	if (corners & KDLowerLeftCorner)
		[path appendBezierPathWithArcFromPoint:NSMakePoint(NSMinX(rect), NSMinY(rect)) toPoint:NSMakePoint(NSMidX(rect), NSMinY(rect)) radius:radius];
	else 
		[path lineToPoint:NSMakePoint(NSMinX(rect), NSMinY(rect))];
	
	[path closePath];
	
	return path;
}

@end
