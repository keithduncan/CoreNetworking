//
//  AFBoolToColor.m
//  Amber
//
//  Created by Keith Duncan on 05/07/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "AFBoolToColor.h"

@implementation AFBoolToColor

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
