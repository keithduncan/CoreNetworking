//
//  NSSortDescriptor+Additions.m
//  Amber
//
//  Created by Keith Duncan on 27/06/2007.
//  Copyright 2007. All rights reserved.
//

#import "NSSortDescriptor+Additions.h"

@implementation NSSortDescriptor (AFAdditions)

+ (NSArray *)ascending:(BOOL)ascending descriptorsForKeys:(NSString *)currentKey, ... {
	NSMutableArray *returnArray = [NSMutableArray array];
	
	if (currentKey != nil) {
		NSSortDescriptor *currentDescriptor = [[NSSortDescriptor alloc] initWithKey:currentKey ascending:ascending];
		[returnArray addObject:currentDescriptor];
		[currentDescriptor release];
		
		va_list keyList;
		va_start(keyList, currentKey);
		
		while ((currentKey = va_arg(keyList, NSString *)) != nil) {
			currentDescriptor = [[NSSortDescriptor alloc] initWithKey:currentKey ascending:ascending];
			[returnArray addObject:currentDescriptor];
			[currentDescriptor release];
		}
		
		va_end(keyList);
	}
	
	return returnArray;
}

@end
