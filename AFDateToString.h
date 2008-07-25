//
//  AFDateToMonthAndYear.h
//  AFStringViewPlugin
//
//  Created by Keith Duncan on 11/02/2007.
//  Copyright 2007 dAX development. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AFDateToString : NSValueTransformer {
	NSString *dateFormat;
	NSDateFormatter *formatter;
}

- (id)initWithDateFormat:(NSString *)format;

@property(copy) NSString *dateFormat;

@end
