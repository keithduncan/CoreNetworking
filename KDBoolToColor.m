//
//  KDBoolToColor.m
//  dawn
//
//  Created by Keith Duncan on 05/07/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "KDBoolToColor.h"

@implementation KDBoolToColor

+ (Class)transformedValueClass {
	return [NSColor class];
}

+ (BOOL)allowsReverseTransformation {
	return NO;
}

- (id)transformedValue:(id)value {
	return (value == nil || ![value boolValue]) ? [NSColor disabledControlTextColor] : [NSColor controlTextColor];
}

@end
