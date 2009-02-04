//
//  NSDate+Additions.m
//  dawn
//
//  Created by Keith Duncan on 03/12/2006.
//  Copyright 2006 thirty-three. All rights reserved.
//

#import "NSDate+Additions.h"

NSString *AFKeyForWeekday(AFWeekday day) {
	switch (day) {
		case SUNDAY:
			return @"sunday";
		case MONDAY:
			return @"monday";
		case TUESDAY:
			return @"tuesday";
		case WEDNESDAY:
			return @"wednesday";
		case THURSDAY:
			return @"thursday";
		case FRIDAY:
			return @"friday";
		case SATURDAY:
			return @"saturday";
	}
	
	[NSException raise:NSInvalidArgumentException format:@"%s, argument \'%d\' was out of range [1,7]", __PRETTY_FUNCTION__, day];
	return nil;
}

@implementation NSDate (AFAdditions)

- (NSUInteger)day {
	return [[[NSCalendar currentCalendar] components:NSDayCalendarUnit fromDate:self] day];
}

- (void)getDay:(NSUInteger *)day month:(NSUInteger *)month year:(NSUInteger *)year {
	NSDateComponents *components = [[NSCalendar currentCalendar] components:(NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit) fromDate:self];
	*day = [components day], *month = [components month], *year = [components year];
}

- (BOOL)components:(NSUInteger)flags matchDate:(NSDate *)otherDate {
	NSDateComponents *selfComponents = [[NSCalendar currentCalendar] components:flags fromDate:self];
	NSDateComponents *dateComponents = [[NSCalendar currentCalendar] components:flags fromDate:otherDate];
	
	return [selfComponents components:flags match:dateComponents];
}

- (NSDate *)dateByAddingDays:(NSInteger)days {
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setDay:days];
	
	NSDate *returnDate = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:self options:0];
	[components release];
	
	return returnDate;
}

- (NSDate *)dateByAddingMonths:(NSInteger)months {
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setMonth:months];
	
	NSDate *returnDate = [[NSCalendar currentCalendar] dateByAddingComponents:components toDate:self options:0];
	[components release];
	
	return returnDate;
}

@end

@implementation NSDateComponents (AFAdditions)

// Note: this is useful where absolute equality isn't important but partial equality is
- (BOOL)components:(NSUInteger)flags match:(NSDateComponents *)components {
	if (self == components) return YES;
	
	if (((flags & NSYearCalendarUnit) == NSYearCalendarUnit) 
		&& ([components year] != [self year])) return NO;
	
	if (((flags & NSSecondCalendarUnit) == NSSecondCalendarUnit) 
		&& ([components second] != [self second])) return NO;
	
	if (((flags & NSMinuteCalendarUnit) == NSMinuteCalendarUnit) 
		&& ([components minute] != [self minute])) return NO;
	
	if (((flags & NSHourCalendarUnit) == NSHourCalendarUnit) 
		&& ([components hour] != [self hour])) return NO;
	
	if (((flags & NSWeekCalendarUnit) == NSWeekCalendarUnit) 
		&& ([components week] != [self week])) return NO;
	
	if (((flags & NSDayCalendarUnit) == NSDayCalendarUnit) 
		&& ([components day] != [self day])) return NO;
	
	if (((flags & NSMonthCalendarUnit) == NSMonthCalendarUnit) 
		&& ([components month] != [self month])) return NO;
	
	if (((flags & NSWeekdayCalendarUnit) == NSWeekdayCalendarUnit) 
		&& ([components weekday] != [self weekday])) return NO;
	
	if (((flags & NSWeekdayOrdinalCalendarUnit) == NSWeekdayOrdinalCalendarUnit) 
		&& ([components weekdayOrdinal] != [self weekdayOrdinal])) return NO;
	
	if (((flags & NSEraCalendarUnit) == NSEraCalendarUnit) 
		&& ([components era] != [self era])) return NO;
	
	return YES;
}

@end
