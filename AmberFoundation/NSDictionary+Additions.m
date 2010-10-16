//
//  NSDictionary+Additions.m
//  Amber
//
//  Created by Keith Duncan on 05/04/2009.
//  Copyright 2009. All rights reserved.
//

#import "NSDictionary+Additions.h"

@implementation NSDictionary (AFAdditions)

+ (id)dictionaryWithString:(NSString *)string separator:(NSString *)separator delimiter:(NSString *)delimiter {
	NSArray *parameterPairs = [string componentsSeparatedByString:delimiter];
	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:[parameterPairs count]];
	
	for (NSString *currentPair in parameterPairs) {
		NSArray *pairComponents = [currentPair componentsSeparatedByString:separator];
		
		NSString *key = ([pairComponents count] >= 1 ? [pairComponents objectAtIndex:0] : nil);
		if (key == nil) continue;
		
		NSString *value = ([pairComponents count] >= 2 ? [pairComponents objectAtIndex:1] : [NSNull null]);
		[parameters setObject:value forKey:key];
	}
	
	return parameters;
}

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
