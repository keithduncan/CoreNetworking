//
//  KDGeometry.h
//  KDCalendarView
//
//  Created by Keith Duncan on 12/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_INLINE NSRect SizeCenteredInRect(NSSize size, NSRect frame) {
	return NSInsetRect(frame, (NSWidth(frame) - size.width)/2.0, (NSHeight(frame) - size.height)/2.0);
}

NS_INLINE NSRect SquareCenteredInRect(CGFloat squareSize, NSRect frame) {
	return NSInsetRect(frame, (NSWidth(frame) - squareSize)/2.0, (NSHeight(frame) - squareSize)/2.0);
}

NS_INLINE NSPoint CentrePointFromRect(NSRect rect) {
	return NSMakePoint(NSMidX(rect), NSMidY(rect));
}

NS_INLINE NSRect RectFromCentrePoint(NSPoint point, NSSize size) {
	return (NSRect){(NSPoint){point.x - (size.width/2.0), point.y - (size.height/2.0)}, (NSSize)size};
}

// This divides the given rect into count pieces and stores them in buffer, buffer must be able to hold count NSRects
extern void KDDivideRect(NSRect rect, NSRectEdge edge, NSUInteger count, NSRectArray buffer);
