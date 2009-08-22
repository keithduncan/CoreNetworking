//
//  NSDictionary+Additions.m
//  Amber
//
//  Created by Keith Duncan on 05/04/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "NSDictionary+Additions.h"

@implementation NSDictionary (AFAdditions)

- (NSDictionary *)diff:(id)container {
	NSMutableDictionary *difference = [NSMutableDictionary dictionary];
	
	for (id currentKey in self) {
		id currentObject = [self objectForKey:currentKey];
		if ([currentObject isEqual:[container valueForKey:currentKey]]) continue;
		
		[difference setObject:[container valueForKey:currentKey] forKey:currentKey];
	}
	
	return difference;
}

- (id)objectForCaseInsensitiveKey:(NSString *)key {
#if NS_BLOCKS_AVAILABLE
	__block id object = nil;
	
	[self enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^ (id currentKey, id currentObject, BOOL *stop) {
		if ([key caseInsensitiveCompare:currentKey] != NSOrderedSame) return;
		
		object = currentObject;
		*stop = YES;
	}];
	
	return object;
#else
	for (NSString *currentKey in self) {
		if ([currentKey caseInsensitiveCompare:key] != NSOrderedSame) continue;
		return [self objectForKey:currentKey];
	}
	
	return nil;
#endif
}

@end
