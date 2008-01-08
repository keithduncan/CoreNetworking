//
//  KDDateToMonthAndYear.h
//  KDStringViewPlugin
//
//  Created by Keith Duncan on 11/02/2007.
//  Copyright 2007 dAX development. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KDDateToString : NSValueTransformer {
	NSString *dateFormat;
	NSDateFormatter *formatter;
}

- (id)initWithDateFormat:(NSString *)format;

@property(copy) NSString *dateFormat;

@end
