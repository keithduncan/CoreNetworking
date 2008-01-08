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

NS_INLINE NSPoint CentrePoint(NSRect rect) {
	return NSMakePoint(NSMidX(rect), NSMidY(rect));
}
