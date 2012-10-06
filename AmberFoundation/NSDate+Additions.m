//
//  NSDate+Additions.m
//  Amber
//
//  Created by Keith Duncan on 03/12/2006.
//  Copyright 2006. All rights reserved.
//

#import "NSDate+Additions.h"

@implementation NSDateComponents (AFAdditions)

// Note: this is useful where absolute equality isn't important but partial equality is
- (BOOL)components:(NSUInteger)flags match:(NSDateComponents *)components {
	if (self == components) {
		return YES;
	}
	
	if (((flags & NSYearCalendarUnit) == NSYearCalendarUnit) && ([components year] != [self year])) {
		return NO;
	}
	
	if (((flags & NSSecondCalendarUnit) == NSSecondCalendarUnit) && ([components second] != [self second])) {
		return NO;
	}
	
	if (((flags & NSMinuteCalendarUnit) == NSMinuteCalendarUnit) && ([components minute] != [self minute])) {
		return NO;
	}
	
	if (((flags & NSHourCalendarUnit) == NSHourCalendarUnit) && ([components hour] != [self hour])) {
		return NO;
	}
	
	if (((flags & NSWeekCalendarUnit) == NSWeekCalendarUnit) && ([components week] != [self week])) {
		return NO;
	}
	
	if (((flags & NSDayCalendarUnit) == NSDayCalendarUnit) && ([components day] != [self day])) {
		return NO;
	}
	
	if (((flags & NSMonthCalendarUnit) == NSMonthCalendarUnit) && ([components month] != [self month])) {
		return NO;
	}
	
	if (((flags & NSWeekdayCalendarUnit) == NSWeekdayCalendarUnit) && ([components weekday] != [self weekday])) {
		return NO;
	}
	
	if (((flags & NSWeekdayOrdinalCalendarUnit) == NSWeekdayOrdinalCalendarUnit) && ([components weekdayOrdinal] != [self weekdayOrdinal])) {
		return NO;
	}
	
	if (((flags & NSEraCalendarUnit) == NSEraCalendarUnit) && ([components era] != [self era])) {
		return NO;
	}
	
	return YES;
}

@end
