//
//  AFDateToMonthAndYear.h
//  Amber
//
//  Created by Keith Duncan on 11/02/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
	@brief
	This class is useful where you cannot insert an NSDateFormatter directly.
 */
@interface AFDateToString : NSValueTransformer {
	NSString *_dateFormat;
	NSDateFormatter *_formatter;
}

- (id)initWithDateFormat:(NSString *)format;

@property (copy) NSString *dateFormat;

@end
