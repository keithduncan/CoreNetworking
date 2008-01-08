 //
//  KDDateToMonthAndYear.m
//  KDStringViewPlugin
//
//  Created by Keith Duncan on 11/02/2007.
//  Copyright 2007 dAX development. All rights reserved.
//

#import "KDDateToString.h"

@implementation KDDateToString

@synthesize dateFormat;

+ (Class)transformedValueClass {
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
	return YES;
}

- (id)init {
	return [self initWithDateFormat:@""];
}

- (id)initWithDateFormat:(NSString *)format {
	[super init];
	
	formatter = [[NSDateFormatter alloc] init];
	self.dateFormat = format;
	
	return self;
}

- (void)dealloc {
	[formatter release];
	self.dateFormat = nil;
	
	[super dealloc];
}

- (NSString *)transformedValue:(NSDate *)value {
	return [value descriptionWithCalendarFormat:dateFormat timeZone:nil locale:nil];
}

- (NSDate *)reverseTransformedValue:(NSString *)value {
	return [formatter dateFromString:value];
}

@end
