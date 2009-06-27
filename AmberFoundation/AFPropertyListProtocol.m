//
//  AFPropertyListProtocol.m
//  AmberFoundation
//
//  Created by Keith Duncan on 11/03/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "AFPropertyListProtocol.h"

static NSString *const AFPropertyListClassNameKey = @"propertyListClass";
static NSString *const AFPropertyListObjectDataKey = @"propertyListData";

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

static BOOL isPlistRepresentation(id object) {
	if (![object isKindOfClass:[NSDictionary class]]) return NO;
	
	NSDictionary *representation = object;
	return ([representation objectForKey:AFPropertyListClassNameKey] != nil && [representation objectForKey:AFPropertyListObjectDataKey] != nil);
}

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
	[self autorelease];
	self = nil;
	
	NSMutableArray *newArray = [[NSMutableArray alloc] initWithCapacity:[propertyListRepresentation count]];
	
	for (id currentObject in propertyListRepresentation) {
		if (!isPlistRepresentation(currentObject)) {
			[newArray addObject:currentObject];
			continue;
		}
		
		id newObject = AFPropertyListRepresentationUnarchive(currentObject);
		[newArray addObject:newObject];
	}
	
	return newArray;
}

- (id)propertyListRepresentation {
	NSMutableArray *propertyListRepresentation = [NSMutableArray array];
	
	for (id <AFPropertyList> currentObject in self) {
		if (isPlistObject(currentObject)) {
			[propertyListRepresentation addObject:currentObject];
			continue;
		}
		
		CFPropertyListRef representation = AFPropertyListRepresentationArchive(currentObject);
		[propertyListRepresentation addObject:(id)representation];
	}
	
	return propertyListRepresentation;
}

@end

@implementation NSDictionary (AFPropertyList)

- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation {
	[self autorelease];
	self = nil;
	
	NSMutableDictionary *newDictionary = [[NSMutableDictionary alloc] initWithCapacity:[propertyListRepresentation count]];
	
	for (NSString *currentKey in propertyListRepresentation) {
		id currentObject = [propertyListRepresentation objectForKey:currentKey];
		
		if (!isPlistRepresentation(currentObject)) {
			[newDictionary setObject:currentObject forKey:currentKey];
			continue;
		}
		
		[newDictionary setObject:AFPropertyListRepresentationUnarchive(currentObject) forKey:currentKey];
	}
	
	return newDictionary;
}

- (id)propertyListRepresentation {	
	NSMutableDictionary *propertyListRepresentation = [NSMutableDictionary dictionaryWithCapacity:[self count]];
	
	for (NSString *currentKey in self) {
		id <AFPropertyList> currentObject = [self objectForKey:currentKey];
		
		if (isPlistObject(currentObject)) {
			[propertyListRepresentation setObject:currentObject forKey:currentKey];
			continue;
		}
		
		[propertyListRepresentation setObject:(id)AFPropertyListRepresentationArchive(currentObject) forKey:currentKey];
	}
	
	return propertyListRepresentation;
}

@end
