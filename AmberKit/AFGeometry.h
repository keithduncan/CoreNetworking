//
//  AFGeometry.h
//  AmberFoundation
//
//  Created by Keith Duncan on 12/06/2007.
//  Copyright 2007. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_MAC && TARGET_OS_IPHONE
#import <CoreGraphics/CoreGraphics.h>
#endif

/*!
	@result
	The middle point of the rect.
 */
NS_INLINE CGPoint AFRectGetCenterPoint(CGRect rect) {
	return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

/*!
	@detail
	Provides an origin for a given the size to create a rect.
 
	@result
	A rect of |size| centered around |point|.
 */
NS_INLINE CGRect AFSizeCenteredAroundPoint(CGSize size, CGPoint point) {
	return CGRectMake(point.x - (size.width/2.0), point.y - (size.height/2.0), size.width, size.height);
}

/*!
	@result
	Rect of |size| around the middle point of |frame|.
 */
NS_INLINE CGRect AFRectCenteredSize(CGRect frame, CGSize size) {
	return AFSizeCenteredAroundPoint(size, AFRectGetCenterPoint(frame));
}

/*!
	@result
	A square size of length |squareSize| cented around the middle point of |frame|.
 */
NS_INLINE CGRect AFRectCenteredSquare(CGRect frame, CGFloat squareSize) {
	return AFSizeCenteredAroundPoint(CGSizeMake(squareSize, squareSize), AFRectGetCenterPoint(frame));
}

/*!
	@result
	Recalculates the origin of |frame| by centering it's .size around |point|.
 */
NS_INLINE CGRect AFRectCenteredAroundPoint(CGRect frame, CGPoint point) {
	return AFSizeCenteredAroundPoint(frame.size, point);
}

/*!
	@brief
	Can be used to center a rectangle in the co-ordinate space of it's parent.
 
	@result
	Recalculates the origin of |bounds| by centering it's .size around the center point of |frame|.
 */
NS_INLINE CGRect AFRectCenteredRect(CGRect frame, CGRect bounds) {
	return AFSizeCenteredAroundPoint(bounds.size, AFRectGetCenterPoint(frame));
}

/*!
	@brief
	Divides the given rect into |count| pieces and stores them in |buffer|.
 
	@detail
	|buffer| must be large enough to store (|count| * sizeof(CGRect)).
 */
extern void AFRectDivideEqually(CGRect rect, CGRectEdge edge, NSUInteger count, CGRect *buffer);
