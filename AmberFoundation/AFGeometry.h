//
//  AFGeometry.h
//  AmberFoundation
//
//  Created by Keith Duncan on 12/06/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_MAC && TARGET_OS_IPHONE
#import <CoreGraphics/CoreGraphics.h>
#endif

/*!
	@function
 */
NS_INLINE CGRect AFRectCenteredSize(CGRect frame, CGSize size) {
	return CGRectInset(frame, (frame.size.width - size.width)/2.0, (frame.size.height - size.height)/2.0);
}

/*!
	@function
 */
NS_INLINE CGRect AFRectCenteredSquare(CGRect frame, CGFloat squareSize) {
	return AFRectCenteredSize(frame, CGSizeMake(squareSize, squareSize));
}

/*!
	@function
 */
NS_INLINE CGPoint AFRectCenterPoint(CGRect rect) {
	return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

/*!
	@function
 */
NS_INLINE CGRect AFRectCenteredAroundPoint(CGRect frame, CGPoint point) {
	return CGRectMake(point.x - (frame.size.width/2.0), point.y - (frame.size.height/2.0), frame.size.width, frame.size.height);
}

/*!
	@function
 */
NS_INLINE CGRect AFRectCenteredRect(CGRect frame, CGRect bounds) {
	return AFRectCenteredAroundPoint(bounds, AFRectCenterPoint(frame));
}

/*!
	@function
	@abstract	Divide the given rect into count pieces and stores them in buffer, buffer must be able to hold count CGRect structs
 */
extern void AFRectDivideEqually(CGRect rect, CGRectEdge edge, NSUInteger count, CGRect *buffer);
