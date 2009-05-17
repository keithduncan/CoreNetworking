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

/*
	@brief
	This functions returns the mid point of the rect.
 */
NS_INLINE CGPoint AFRectGetCenterPoint(CGRect rect) {
	return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

/*
	@brief
	This function centers a size around a given point. This provide the size with an origin.
 */
NS_INLINE CGRect AFSizeCenteredAroundPoint(CGSize size, CGPoint point) {
	return CGRectMake(point.x - (size.width/2.0), point.y - (size.height/2.0), size.width, size.height);
}

/*
	@brief
	This function centers a size around the center point of a rect.
 */
NS_INLINE CGRect AFRectCenteredSize(CGRect frame, CGSize size) {
	return AFSizeCenteredAroundPoint(size, AFRectGetCenterPoint(frame));
}

/*
	@brief
	This function centers a square size in the middle of a rectangle.
 */
NS_INLINE CGRect AFRectCenteredSquare(CGRect frame, CGFloat squareSize) {
	return AFSizeCenteredAroundPoint(CGSizeMake(squareSize, squareSize), AFRectGetCenterPoint(frame));
}

/*
	@brief
	This function centers a rectangle around a center point.
	It takes the size out of the |frame| and recalculates an origin.
 */
NS_INLINE CGRect AFRectCenteredAroundPoint(CGRect frame, CGPoint point) {
	return AFSizeCenteredAroundPoint(frame.size, point);
}

/*
	@brief
	This function centers a rect inside another.
	It can be used to center a rectangle in the co-ordinate space of it's parent.
 */
NS_INLINE CGRect AFRectCenteredRect(CGRect frame, CGRect bounds) {
	return AFSizeCenteredAroundPoint(bounds.size, AFRectGetCenterPoint(frame));
}

/*!
	@brief
	This functions divides the given rect into |count| pieces and stores them in |buffer|.
	Buffer must be large enough to store (|count| * sizeof(CGRect)).
 */
extern void AFRectDivideEqually(CGRect rect, CGRectEdge edge, NSUInteger count, CGRect *buffer);
