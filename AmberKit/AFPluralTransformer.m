//
//  AFPluralTransformer.m
//  Amber
//
//  Created by Keith Duncan on 21/06/2007.
//  Copyright 2007. All rights reserved.
//

#import "AFPluralTransformer.h"

@implementation AFPluralTransformer

+ (Class)transformedValueClass {
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
	return NO;
}

- (NSString *)transformedValue:(id)value {
	if (value == nil) return @"";
	
	if ([value conformsToProtocol:@protocol(NSFastEnumeration)]) {
		return ([value count] > 1 ? @"s" : @"");
	} else if ([value isKindOfClass:[NSNumber class]]) {
		return ([value integerValue] > 1 ? @"s" : @"");
	}
	
	return nil;
}

@end
