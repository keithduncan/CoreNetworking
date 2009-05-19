//
//  NSControl+Additions.h
//  Amber
//
//  Created by Keith Duncan on 16/05/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSControl (AFAdditions)

/*!
	@result
	The application's active status, and the window key status.
	You should observe notifications to determine when this property changes.
 */
- (BOOL)shouldDrawKey;

@end
