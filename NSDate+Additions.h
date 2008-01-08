//
//  NSDate+Additions.h
//  dawn
//
//  Created by Keith Duncan on 03/12/2006.
//  Copyleft 2006 dAX development. All rights reserved.
//

#import <Foundation/Foundation.h>

enum {
	SUNDAY = 1,
	MONDAY,
	TUESDAY,
	WEDNESDAY,
	THURSDAY,
	FRIDAY,
	SATURDAY
};
typedef NSUInteger Weekday;

extern NSString *KeyForWeekday(Weekday day);

enum {
	JANUARY = 1,
	FEBRUARY,
	MARCH,
	APRIL,
	MAY,
	JUNE,
	JULY,
	AUGUST,
	SEPTEMBER,
	OCTOBER,
	NOVEMBER,
	DECEMBER
};
typedef NSUInteger Month;


@interface NSDate (Additions)

- (NSUInteger)day;

- (void)getDay:(NSUInteger *)day month:(NSUInteger *)month year:(NSUInteger *)year;
- (BOOL)components:(NSUInteger)flags matchDate:(NSDate *)otherDate;

- (NSDate *)dateByAddingDays:(NSInteger)days;
- (NSDate *)dateByAddingMonths:(NSInteger)months;

@end
