//
//  KDPropertyListProtocol.h
//  KDCalendarView
//
//  Created by Keith Duncan on 11/03/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *const KDClassNameKey;
extern NSString *const KDObjectDataKey;

@protocol KDPropertyListProtocol
- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation;
- (id)propertyListRepresentation;
@end

@interface NSArray (KDPropertyList) <KDPropertyListProtocol>
+ (id)arrayWithPropertyListRepresentation:(id)propertyListRepresentation;
@end

@interface NSSet (KDPropertyList) <KDPropertyListProtocol>
+ (id)setWithPropertyListRepresentation:(id)propertyListRepresentation;
@end
