//
//  NSDate+Additions.h
//  Amber
//
//  Created by Keith Duncan on 03/12/2006.
//  Copyleft 2006 thirty-three. All rights reserved.
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
typedef NSUInteger AFWeekday;

extern NSString *AFKeyForWeekday(AFWeekday day);


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
typedef NSUInteger AFMonth;


@interface NSDate (AFAdditions)
- (NSUInteger)day;

- (void)getDay:(NSUInteger *)day month:(NSUInteger *)month year:(NSUInteger *)year;

- (BOOL)components:(NSUInteger)flags matchDate:(NSDate *)otherDate;

- (NSDate *)dateByAddingDays:(NSInteger)days;
- (NSDate *)dateByAddingMonths:(NSInteger)months;
@end

@interface NSDateComponents (AFAdditions)
- (BOOL)components:(NSUInteger)flags match:(NSDateComponents *)components;
@end
