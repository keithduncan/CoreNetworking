//
//  NSDictionary+AFNetworkAdditions.m
//  CoreNetworking
//
//  Created by Keith Duncan on 17/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import "NSDictionary+AFNetworkAdditions.h"

@implementation NSDictionary (AFNetworkAdditions)

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
