//
//  AFGeometry.h
//  AFCalendarView
//
//  Created by Keith Duncan on 12/06/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_MAC && (defined(TARGET_OS_IPHONE) && !TARGET_OS_IPHONE)
#import <CoreGraphics/CoreGraphics.h>
#endif

NS_INLINE CGRect AFRectCenteredSize(CGRect frame, CGSize size) {
	return CGRectInset(frame, (frame.size.width - size.width)/2.0, (frame.size.height - size.height)/2.0);
}

NS_INLINE CGRect AFRectCenteredSquare(CGRect frame, CGFloat squareSize) {
	return CGRectInset(frame, (frame.size.width - squareSize)/2.0, (frame.size.height - squareSize)/2.0);
}

NS_INLINE CGRect AFPointCenteredSize(CGPoint point, CGSize size) {
	return (CGRect){(CGPoint){point.x - (size.width/2.0), point.y - (size.height/2.0)}, (CGSize)size};
}

NS_INLINE CGPoint AFRectCenterPoint(CGRect rect) {
	return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

// This divides the given rect into count pieces and stores them in buffer, buffer must be able to hold count CGRect structs
extern void AFRectDivideEqually(CGRect rect, CGRectEdge edge, NSUInteger count, CGRect *buffer);
