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
+ (NSBezierPath *)bezierPathWithString:(NSString *)text inFont:(NSFont *)font aligned:(NSTextAlignment)aligned inFrame:(NSRect)frame __attribute__((deprecated));

- (void)appendBezierPathWithString:(NSString *)text inFont:(NSFont *)font;

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect corners:(AFRoundedCornerOptions)corners radius:(CGFloat)radius;
@end
