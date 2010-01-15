//
//  NSString+Additions.m
//  Amber
//
//  Created by Keith Duncan on 06/12/2007.
//  Copyright 2007 Keith Duncan. All rights reserved.
//

#import "NSString+Additions.h"

#import "NSArray+Additions.h"

@implementation NSString (AFAdditions)

- (NSString *)stringByTrimmingWhiteSpace {
	NSMutableString *newString = [[self mutableCopy] autorelease];
	CFStringTrimWhitespace((CFMutableStringRef)newString);
	return newString;
}

- (BOOL)isEmpty {
	return [[self stringByTrimmingWhiteSpace] isEqualToString:@""];
}

- (NSString *)stringByAppendingElipsisAfterCharacters:(NSUInteger)count {
	if ([self length] <= count) return self;
	else return [[self substringToIndex:count] stringByAppendingString:@"..."];
}

@end

@implementation NSString (AFKeyValueCoding)

- (NSArray *)keyPathComponents {
	return [self componentsSeparatedByString:@"."];
}

- (NSString *)lastKeyPathComponent {
	return [[self keyPathComponents] lastObject];
}

+ (NSString *)stringWithKeyPathComponents:(NSString *)component, ... {
	NSMutableArray *components = [NSMutableArray array];
	
	if (component != nil) {
		va_list keyList;
		va_start(keyList, component);
		
		do {
			[components addObject:component];
		} while (component = va_arg(keyList, NSString *));
		
		va_end(keyList);
	}
	
	return [components componentsJoinedByString:@"."];
}

- (NSString *)stringByAppendingKeyPath:(NSString *)keyPath {
	return [self stringByAppendingFormat:@".%@", keyPath, nil];
}

- (NSString *)stringByRemovingKeyPathComponentAtIndex:(NSUInteger)index {
	NSArray *keyPathComponents = [self keyPathComponents];
	if (!AFArrayContainsIndex(keyPathComponents, index)) {
		[NSException raise:NSRangeException format:@"%s, attempting to access keypath component at index %d beyond range.", __PRETTY_FUNCTION__, index, nil];
		return nil;
	}
	
	NSMutableArray *mutableKeyPathComponents = [keyPathComponents mutableCopy];
	[mutableKeyPathComponents removeObjectAtIndex:index];
	NSString *newKeyPath = [mutableKeyPathComponents componentsJoinedByString:@"."];
	[mutableKeyPathComponents release];
	
	return newKeyPath;
}

- (NSString *)stringByRemovingLastKeyPathComponent {
	return [self stringByRemovingKeyPathComponentAtIndex:([[self keyPathComponents] count] - 1)];
}

@end
