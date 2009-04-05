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

@end
