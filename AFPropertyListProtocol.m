//
//  AFPropertyListProtocol.m
//  dawn
//
//  Created by Keith Duncan on 14/03/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "AFPropertyListProtocol.h"

NSString *const AFClassNameKey = @"propertyListClass";
NSString *const AFObjectDataKey = @"propertyListData";

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
	return ([object isKindOfClass:[NSDictionary class]] && [object count] == 2 && [object objectForKey:AFClassNameKey] != nil && [object objectForKey:AFObjectDataKey] != nil);
}

@implementation NSArray (AFPropertyList)

+ (id)arrayWithPropertyListRepresentation:(id)propertyListRepresentation {
	return [[[self alloc] initWithPropertyListRepresentation:propertyListRepresentation] autorelease];
}

- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation {
	@try {
		NSMutableArray *newArray = [[NSMutableArray alloc] init];
		for (id currentObject in propertyListRepresentation) {			
			if (isPlistRepresentation(currentObject)) {				
				id newObject = [[NSClassFromString([currentObject objectForKey:AFClassNameKey]) alloc] initWithPropertyListRepresentation:[currentObject valueForKey:AFObjectDataKey]];
				[newArray addObject:newObject];
				[newObject release];
			} else [newArray addObject:currentObject];
		}
		
		return newArray;
	}
	@catch (NSException *exception) {
		@throw;
	}
	@finally {
		[self release];
	}
	
	return nil;
}

- (id)propertyListRepresentation {
	//if (!isPlistObject(self)) [NSException raise:NSInternalInconsistencyException format:[NSString stringWithFormat:@"-[NSArray(AFPropertyList) %s], tried to archive object \"%@\", which doesn't conform to the AFPropertyListProtocol", _cmd, self]];
	
	NSMutableArray *propertyListRepresentation = [NSMutableArray array];
	for (NSObject <AFPropertyListProtocol> *currentObject in self) {		
		NSDictionary *objectDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											[currentObject propertyListRepresentation], AFObjectDataKey, 
											NSStringFromClass([currentObject class]), AFClassNameKey, nil];
		
		[propertyListRepresentation addObject:objectDictionary];
	}
	
	return propertyListRepresentation;
}

@end

@implementation NSSet (AFPropertyList)

+ (id)setWithPropertyListRepresentation:(id)propertyListRepresentation {
	return [[[self alloc] initWithPropertyListRepresentation:propertyListRepresentation] autorelease];
}

- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation {
	@try {
		return [[NSSet alloc] initWithArray:[NSArray arrayWithPropertyListRepresentation:propertyListRepresentation]];
	}
	@catch (NSException *exception) {
		@throw;
	}
	@finally {
		[self release];
	}
	
	return nil;
}

- (id)propertyListRepresentation {
	return [[self allObjects] propertyListRepresentation];
}

@end

#if 0
@implementation NSDictionary (AFPropertyList)

+ (id)dictionaryWithPropertyListRepresentation:(id)propertyListRepresentation {
	return [[[self alloc] initWithPropertyListRepresentation:propertyListRepresentation] autorelease];
}

- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation {
	
}

- (id)propertyListRepresentation {
	if (!isPlistObject(self)) [NSException raise:NSInternalInconsistencyException format:[NSString stringWithFormat:@"-[NSDictionary(AFPropertyList) %s], tried to archive object \"%@\", which doesn't conform to the AFPropertyListProtocol", _cmd, self]];
	
	NSMutableDictionary *propertyListRepresentation = [NSMutableDictionary dictionaryWithCapacity:[self count]];
	
	for (id currentKey in self) {
		if (isPlistObject(cu [self objectForKey:currentKey]
	}
	
	return propertyListRepresentation;
}

@end
#endif
