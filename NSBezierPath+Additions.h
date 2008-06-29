//
//  NSBezierPath+Additions.h
//  KDStringView
//
//  Created by Keith Duncan on 24/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum {
	KDLowerLeftCorner = 0x01,
	KDLowerRightCorner = 0x02,
	KDUpperLeftCorner = 0x04,
	KDUpperRightCorner = 0x08
};
typedef NSUInteger KDRoundedCornerOptions;

@interface NSBezierPath (Additions)
+ (NSBezierPath *)bezierPathWithString:(NSString *)text inFont:(NSFont *)font;
+ (NSBezierPath *)bezierPathWithString:(NSString *)text inFont:(NSFont *)font aligned:(NSTextAlignment)aligned inFrame:(NSRect)frame;

- (void)appendBezierPathWithString:(NSString *)text inFont:(NSFont *)font;

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect corners:(KDRoundedCornerOptions)corners radius:(CGFloat)radius;
@end
