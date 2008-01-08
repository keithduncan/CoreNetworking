//
//  KDNSDate.m
//  dawn
//
//  Created by Keith Duncan on 03/12/2006.
//  Copyright 2006 dAX development. All rights reserved.
//

#import "NSDate+Additions.h"

NSString *KeyForWeekday(Weekday day) {
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
	
	[NSException raise:NSInvalidArgumentException format:@"KeyForWeekday(), argument \'%d\' was out of range 1 -> 7", day];
	return nil;
}

@implementation NSDate (Additions)

- (NSUInteger)day {
	return [[[NSCalendar autoupdatingCurrentCalendar] components:NSDayCalendarUnit fromDate:self] day];
}

- (void)getDay:(NSUInteger *)day month:(NSUInteger *)month year:(NSUInteger *)year {
	NSDateComponents *components = [[NSCalendar autoupdatingCurrentCalendar] components:(NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit) fromDate:self];
	*day = [components day], *month = [components month], *year = [components year];
}

- (BOOL)components:(NSUInteger)flags matchDate:(NSDate *)otherDate {
	NSDateComponents *selfComponents = [[NSCalendar autoupdatingCurrentCalendar] components:flags fromDate:self];
	NSDateComponents *dateComponents = [[NSCalendar autoupdatingCurrentCalendar] components:flags fromDate:otherDate];
	
	if ((flags & NSYearCalendarUnit) && ([dateComponents year] != [selfComponents year])) return NO;
	if ((flags & NSSecondCalendarUnit) && ([dateComponents second] != [selfComponents second])) return NO;
	if ((flags & NSMinuteCalendarUnit) && ([dateComponents minute] != [selfComponents minute])) return NO;
	if ((flags & NSHourCalendarUnit) && ([dateComponents hour] != [selfComponents hour])) return NO;
	if ((flags & NSWeekCalendarUnit) && ([dateComponents week] != [selfComponents week])) return NO;
	if ((flags & NSDayCalendarUnit) && ([dateComponents day] != [selfComponents day])) return NO;
	if ((flags & NSMonthCalendarUnit) && ([dateComponents month] != [selfComponents month])) return NO;
	if ((flags & NSWeekdayCalendarUnit) && ([dateComponents weekday] != [selfComponents weekday])) return NO;
	if ((flags & NSWeekdayOrdinalCalendarUnit) && ([dateComponents weekdayOrdinal] != [selfComponents weekdayOrdinal])) return NO;
	if ((flags & NSEraCalendarUnit) && ([dateComponents era] != [selfComponents era])) return NO;
	
	return YES;
}

- (NSDate *)dateByAddingDays:(NSInteger)days {
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setDay:days];
	
	NSDate *returnDate = [[NSCalendar autoupdatingCurrentCalendar] dateByAddingComponents:components toDate:self options:0];
	[components release];
	
	return returnDate;
}

- (NSDate *)dateByAddingMonths:(NSInteger)months {
	NSDateComponents *components = [[NSDateComponents alloc] init];
	[components setMonth:months];
	
	NSDate *returnDate = [[NSCalendar autoupdatingCurrentCalendar] dateByAddingComponents:components toDate:self options:0];
	[components release];
	
	return returnDate;
}

@end
