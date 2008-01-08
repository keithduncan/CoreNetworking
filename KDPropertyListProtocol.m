//
//  KDPropertyListProtocol.m
//  dawn
//
//  Created by Keith Duncan on 14/03/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "KDPropertyListProtocol.h"

NSString *const KDClassNameKey = @"propertyListClass";
NSString *const KDObjectDataKey = @"propertyListData";

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
	return ([object isKindOfClass:[NSDictionary class]] && [object count] == 2 && [object objectForKey:KDClassNameKey] != nil && [object objectForKey:KDObjectDataKey] != nil);
}

@implementation NSArray (KDPropertyList)

+ (id)arrayWithPropertyListRepresentation:(id)propertyListRepresentation {
	return [[[self alloc] initWithPropertyListRepresentation:propertyListRepresentation] autorelease];
}

- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation {
	@try {
		NSMutableArray *newArray = [[NSMutableArray alloc] init];
		for (id currentObject in propertyListRepresentation) {			
			if (isPlistRepresentation(currentObject)) {				
				id newObject = [[NSClassFromString([currentObject objectForKey:KDClassNameKey]) alloc] initWithPropertyListRepresentation:[currentObject valueForKey:KDObjectDataKey]];
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
	//if (!isPlistObject(self)) [NSException raise:NSInternalInconsistencyException format:[NSString stringWithFormat:@"-[NSArray(KDPropertyList) %s], tried to archive object \"%@\", which doesn't conform to the KDPropertyListProtocol", _cmd, self]];
	
	NSMutableArray *propertyListRepresentation = [NSMutableArray array];
	for (NSObject <KDPropertyListProtocol> *currentObject in self) {		
		NSDictionary *objectDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											[currentObject propertyListRepresentation], KDObjectDataKey, 
											NSStringFromClass([currentObject class]), KDClassNameKey, nil];
		
		[propertyListRepresentation addObject:objectDictionary];
	}
	
	return propertyListRepresentation;
}

@end

@implementation NSSet (KDPropertyList)

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
@implementation NSDictionary (KDPropertyList)

+ (id)dictionaryWithPropertyListRepresentation:(id)propertyListRepresentation {
	return [[[self alloc] initWithPropertyListRepresentation:propertyListRepresentation] autorelease];
}

- (id)initWithPropertyListRepresentation:(id)propertyListRepresentation {
	
}

- (id)propertyListRepresentation {
	if (!isPlistObject(self)) [NSException raise:NSInternalInconsistencyException format:[NSString stringWithFormat:@"-[NSDictionary(KDPropertyList) %s], tried to archive object \"%@\", which doesn't conform to the KDPropertyListProtocol", _cmd, self]];
	
	NSMutableDictionary *propertyListRepresentation = [NSMutableDictionary dictionaryWithCapacity:[self count]];
	
	for (id currentKey in self) {
		if (isPlistObject(cu [self objectForKey:currentKey]
	}
	
	return propertyListRepresentation;
}

@end
#endif
