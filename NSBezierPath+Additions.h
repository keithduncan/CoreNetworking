//
//  NSBezierPath+Additions.h
//  AFStringView
//
//  Created by Keith Duncan on 24/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum {
	AFLowerLeftCorner	= 1 << 0,
	AFLowerRightCorner	= 1 << 1,
	AFUpperLeftCorner	= 1 << 2,
	AFUpperRightCorner	= 1 << 3,
};
typedef NSUInteger AFRoundedCornerOptions;

@interface NSBezierPath (AFAdditions)
+ (NSBezierPath *)bezierPathWithString:(NSString *)text inFont:(NSFont *)font;
- (void)appendBezierPathWithString:(NSString *)text inFont:(NSFont *)font;

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect corners:(AFRoundedCornerOptions)corners radius:(CGFloat)radius;
- (void)appendBezierPathWithRoundedRect:(NSRect)rect corners:(AFRoundedCornerOptions)corners radius:(CGFloat)radius;

- (void)applyInnerShadow:(NSShadow *)shadow;
@end

extern void AKDrawStringAlignedInFrame(NSString *text, NSFont *font, NSTextAlignment alignment, NSRect frame);
