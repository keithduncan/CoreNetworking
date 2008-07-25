//
//  NSSortDescriptor+Additions.m
//  Shared Source
//
//  Created by Keith Duncan on 27/06/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSSortDescriptor+Additions.h"

@implementation NSSortDescriptor (AFAdditions)

+ (NSArray *)ascending:(BOOL)ascending descriptorsForKeys:(NSString *)currentKey, ... {
	va_list keyList;
	NSMutableArray *returnArray = [NSMutableArray array];
	
	if (currentKey != nil) {
		NSSortDescriptor *currentDescriptor = [[NSSortDescriptor alloc] initWithKey:currentKey ascending:ascending];
		[returnArray addObject:currentDescriptor];
		[currentDescriptor release];
		
		va_start(keyList, currentKey);
		
		while (currentKey = va_arg(keyList, NSString *)) {
			currentDescriptor = [[NSSortDescriptor alloc] initWithKey:currentKey ascending:ascending];
			[returnArray addObject:currentDescriptor];
			[currentDescriptor release];
		}
		
		va_end(keyList);
	}
	
	return returnArray;
}

@end
