//
//  AFPropertyListProtocol.h
//  AFCalendarView
//
//  Created by Keith Duncan on 11/03/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AFPropertyList <NSObject>
- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation;
- (id)propertyListRepresentation;
@end

@interface NSArray (AFPropertyList) <AFPropertyList>

@end

@interface NSDictionary (AFPropertyList) <AFPropertyList>

@end

extern CFPropertyListRef AFPropertyListRepresentationArchive(id <AFPropertyList> object);
extern id AFPropertyListRepresentationUnarchive(CFPropertyListRef propertyListRepresentation);
