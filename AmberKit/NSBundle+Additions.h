//
//  NSBundle+Additions.h
//  Amber
//
//  Created by Keith Duncan on 16/10/2007.
//  Copyright 2007. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSBundle (AKAdditions)

/*!
	@brief
	The Info.plist CFBundleIconFile, preloaded and cached into an NSImage.
 */
- (NSImage *)icon;

@end
