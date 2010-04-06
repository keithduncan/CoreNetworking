//
//  NSControl+Additions.m
//  Amber
//
//  Created by Keith Duncan on 16/05/2009.
//  Copyright 2009. All rights reserved.
//

#import "NSControl+Additions.h"

@implementation NSControl (AFAdditions)

- (BOOL)shouldDrawKey {
	return ([[NSApplication sharedApplication] isActive] && [[self window] isKeyWindow]);
}

@end
