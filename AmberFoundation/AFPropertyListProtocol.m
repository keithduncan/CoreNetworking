//
//  AFPropertyListProtocol.m
//  dawn
//
//  Created by Keith Duncan on 14/03/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "AFPropertyListProtocol.h"

static BOOL isPlistObject(id object) {
	if ([object isKindOfClass:[NSString class]]) return YES;
	else if ([object isKindOfClass:[NSData class]]) return YES;
    else if ([object isKindOfClass:[NSDate class]]) return YES;
	else if ([object isKindOfClass:[NSNumber class]]) return YES;
	else if ([object isKindOfClass:[NSArray class]]) {
		for (id currentObject in (NSArray *)object) {
			if (!isPlistObject(currentObject)) return NO;
		}
		
		return YES;
    } else if ([object isKindOfClass:[NSDictionary class]]) {
		for (id currentKey in (NSDictionary *)object) {
			if (!isPlistObject(currentKey)) return NO;
			if (!isPlistObject([object objectForKey:currentKey])) return NO;
		}
		
		return YES;
    } else return NO;
}

static NSString *const AFPropertyListClassNameKey = @"propertyListClass";
static NSString *const AFPropertyListObjectDataKey = @"propertyListData";

CFPropertyListRef AFPropertyListRepresentationArchive(id <AFPropertyList> object) {
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[object propertyListRepresentation], AFPropertyListObjectDataKey,
			NSStringFromClass([object class]), AFPropertyListClassNameKey,
			nil];
}

id AFPropertyListRepresentationUnarchive(CFPropertyListRef propertyListRepresentation) {
	return [[[NSClassFromString([(NSDictionary *)propertyListRepresentation objectForKey:AFPropertyListClassNameKey]) alloc] initWithPropertyListRepresentation:[(NSDictionary *)propertyListRepresentation objectForKey:AFPropertyListObjectDataKey]] autorelease];
}

@implementation NSArray (AFPropertyList)

- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation {
	[self release];
	
	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:[propertyListRepresentation count]];
	
	for (id currentObject in propertyListRepresentation) {
		id newObject = AFPropertyListRepresentationUnarchive(currentObject);
		[newArray addObject:newObject];
	}
	
	// Note: this allows us to return a subclass
	return [[[self class] alloc] initWithArray:newArray];
}

- (id)propertyListRepresentation {
	NSMutableArray *propertyListRepresentation = [NSMutableArray array];
	
	for (id <AFPropertyList> currentObject in self) {	
		CFPropertyListRef representation = AFPropertyListRepresentationArchive(currentObject);
		[propertyListRepresentation addObject:(id)representation];
	}
	
	return propertyListRepresentation;
}

@end

@implementation NSDictionary (AFPropertyList)

- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation {
	[self release];
	
	NSMutableDictionary *newDictionary = [NSMutableDictionary dictionaryWithCapacity:[propertyListRepresentation count]];
	
	for (NSString *currentKey in propertyListRepresentation) {
		[newDictionary setObject:AFPropertyListRepresentationUnarchive([propertyListRepresentation objectForKey:currentKey]) forKey:currentKey];
	}
	
	// Note: this allows us to return a subclass
	return [[[self class] alloc] initWithDictionary:newDictionary];
}

- (id)propertyListRepresentation {	
	NSMutableDictionary *propertyListRepresentation = [NSMutableDictionary dictionaryWithCapacity:[self count]];
	
	for (NSString *currentKey in self) {
		id <AFPropertyList> currentObject = [self objectForKey:currentKey];
		if (!isPlistObject(currentObject)) {
			[NSException raise:NSInternalInconsistencyException format:@"%s, %@ is not a plist object type, cannot serialize", __PRETTY_FUNCTION__, currentObject, nil];
			return nil;
		}
		
		[propertyListRepresentation setObject:(id)AFPropertyListRepresentationArchive(currentObject) forKey:currentKey];
	}
	
	return propertyListRepresentation;
}

@end
