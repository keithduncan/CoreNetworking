//
//  KDPluralTransformer.m
//  iLog fitness
//
//  Created by Keith Duncan on 21/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "KDPluralTransformer.h"

@implementation KDPluralTransformer

+ (Class)transformedValueClass {
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
	return NO;
}

- (NSString *)transformedValue:(NSArray *)value {
	if (value == nil) return @"";
	
	return ([value count] > 1 ? @"s" : @"");
}

@end
