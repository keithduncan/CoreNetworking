//
//  NSString+Additions.m
//  Amber
//
//  Created by Keith Duncan on 06/12/2007.
//  Copyright 2007 Keith Duncan. All rights reserved.
//

#import "NSString+Additions.h"

@implementation NSString (AFAdditions)

- (NSString *)trimWhiteSpace {
	NSMutableString *newString = [[self mutableCopy] autorelease];
	CFStringTrimWhitespace((CFMutableStringRef)newString);
	return newString;
}

- (BOOL)isEmpty {
	return [[self trimWhiteSpace] isEqualToString:@""];
}

- (NSString *)stringByAppendingElipsisAfterCharacters:(NSUInteger)count {
	if ([self length] <= count) return self;
	else return [[self substringToIndex:count] stringByAppendingString:@"..."];
}

@end

@implementation NSString (AFKeyValueCoding)

static NSString *const AFKeyPathComponentSeparator = @".";

+ (NSString *)keyPathForComponents:(NSString *)component, ... {
	va_list keyList;
	NSMutableString *returnString = [NSMutableString string];
	
	if (component != nil) {
		[returnString appendString:component];
		
		va_start(keyList, component);
		
		while (component = va_arg(keyList, NSString *)) {
			[returnString appendFormat:@"%@%@", AFKeyPathComponentSeparator, component];
		}
		
		va_end(keyList);
	}
	
	return returnString;
}

- (NSArray *)keyPathComponents {
	return [self componentsSeparatedByString:AFKeyPathComponentSeparator];
}

- (NSString *)lastKeyPathComponent {
	return [[self keyPathComponents] lastObject];
}

- (NSString *)stringByAppendingKeyPath:(NSString *)keyPath {
	return [self stringByAppendingFormat:@"%@%@", AFKeyPathComponentSeparator, keyPath];
}

- (NSString *)stringByRemovingKeyPathComponentAtIndex:(NSUInteger)index {
	NSArray *keyPathComponents = [self keyPathComponents];
	if (!NSLocationInRange(index, (NSRange){0, [keyPathComponents count]})) [NSException raise:NSRangeException format:@"-[NSString(AFKeyPathUtilities) &s] attempting to access keypath component at index %d beyond range.", _cmd, index];
	
	NSMutableArray *mutableKeyPathComponents = [keyPathComponents mutableCopy];
	[mutableKeyPathComponents removeObjectAtIndex:index];
	
	NSString *newKeyPath = [mutableKeyPathComponents componentsJoinedByString:AFKeyPathComponentSeparator];
	[mutableKeyPathComponents release];
	
	return newKeyPath;
}

@end
