//
//  NSDate+Additions.h
//  Amber
//
//  Created by Keith Duncan on 03/12/2006.
//  Copyleft 2006. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\file
 */

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

/*!
	\brief
	This function returns a key suitable for use in a dictionary or NSUserDefaults.
	It is not localised and must not be displayed to the user. Use NSDateFormatter to access localised date strings.
 */
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

/*!
	\return
	The day of the month.
 */
- (NSUInteger)day;

/*!
	\brief
	Simple convenience method, I found myself frequently fetching the day, month and year from NSDateComponents.
 */
- (void)getDay:(NSUInteger *)day month:(NSUInteger *)month year:(NSUInteger *)year;

/*!
	\brief
	Creates NSDateComponents for each the receiver and |otherDate| using the flags, and returns the result of <tt>-[NSDateComponents components:match:]</tt>.
 */
- (BOOL)components:(NSUInteger)flags matchDate:(NSDate *)otherDate;

- (NSDate *)dateByAddingDays:(NSInteger)days;
- (NSDate *)dateByAddingMonths:(NSInteger)months;

@end

@interface NSDateComponents (AFAdditions)

/*!
	\brief
	Checks each of the components in |flags| for equality against |components|.
 */
- (BOOL)components:(NSUInteger)flags match:(NSDateComponents *)components;

@end
