//
//  NSBezierPath+Additions.h
//  AFStringView
//
//  Created by Keith Duncan on 24/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum {
	AFLowerLeftCorner = 0x01,
	AFLowerRightCorner = 0x02,
	AFUpperLeftCorner = 0x04,
	AFUpperRightCorner = 0x08
};
typedef NSUInteger AFRoundedCornerOptions;

@interface NSBezierPath (AFAdditions)
+ (NSBezierPath *)bezierPathWithString:(NSString *)text inFont:(NSFont *)font;
- (void)appendBezierPathWithString:(NSString *)text inFont:(NSFont *)font;

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect corners:(AFRoundedCornerOptions)corners radius:(CGFloat)radius;
- (void)appendBezierPathWithRoundedRect:(NSRect)rect corners:(AFRoundedCornerOptions)corners radius:(CGFloat)radius;

- (void)applyInnerShadow:(NSShadow *)shadow;
@end

extern void AFDrawStringAlignedInFrame(NSString *text, NSFont *font, NSTextAlignment alignment, NSRect frame);
