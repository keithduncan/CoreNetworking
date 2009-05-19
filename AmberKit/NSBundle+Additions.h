//
//  NSBundle+Additions.h
//  Amber
//
//  Created by Keith Duncan on 16/10/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*!
	@brief
	This Info.plist key should reference a filename in the bundle's Resources folder.
	It is for display in NSAlert style windows.
 */
extern NSString *const AFAlertIconFileKey;

@interface NSBundle (AKAdditions)

/*!
	@brief
	The Info.plist CFBundleIconFile, preloaded and cached into an NSImage.
 */
- (NSImage *)icon;

/*!
	@result
	The AFAlertIconFileKey, preloaded and cached into an NSImage.
 */
- (NSImage *)alertIcon;

@end
