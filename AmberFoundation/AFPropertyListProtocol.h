//
//  AFPropertyListProtocol.h
//  AFCalendarView
//
//  Created by Keith Duncan on 11/03/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const AFClassNameKey;
extern NSString *const AFObjectDataKey;

@protocol AFPropertyListProtocol
- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation;
- (id)propertyListRepresentation;
@end

@interface NSArray (AFPropertyList)
+ (id)arrayWithPropertyListRepresentation:(id)propertyListRepresentation;
@end
