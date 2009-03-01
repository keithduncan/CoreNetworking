//
//  NSBundle+Additions.h
//  dawn
//
//  Created by Keith Duncan on 16/10/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *const AFAlertIconFileKey;

@interface NSBundle (AKAdditions)
- (NSImage *)icon;
- (NSImage *)alertIcon;
@end
