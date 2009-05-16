//
//  NSControl+Additions.m
//  Amber
//
//  Created by Keith Duncan on 16/05/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "NSControl+Additions.h"

@implementation NSControl (Additions)

- (BOOL)shouldDrawKey {
	return ([[NSApplication sharedApplication] isActive] && [[self window] isKeyWindow]);
}

@end
