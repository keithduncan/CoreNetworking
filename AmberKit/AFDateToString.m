 //
//  AFDateToMonthAndYear.m
//  Amber
//
//  Created by Keith Duncan on 11/02/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "AFDateToString.h"

@interface AFDateToString ()
@property (retain) NSDateFormatter *formatter;
@end

@implementation AFDateToString

@synthesize dateFormat=_dateFormat;
@synthesize formatter=_formatter;

+ (Class)transformedValueClass {
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
	return YES;
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	self.formatter = [[[NSDateFormatter alloc] init] autorelease];
	
	return self;
}

- (id)initWithDateFormat:(NSString *)format {
	self = [self init];
	if (self == nil) return nil;
	
	self.dateFormat = format;
	
	return self;
}

- (void)dealloc {
	self.dateFormat = nil;
	self.formatter = nil;
	
	[super dealloc];
}

- (NSString *)transformedValue:(NSDate *)value {
	return [value descriptionWithCalendarFormat:self.dateFormat timeZone:nil locale:nil];
}

- (NSDate *)reverseTransformedValue:(NSString *)value {
	return [self.formatter dateFromString:value];
}

@end
