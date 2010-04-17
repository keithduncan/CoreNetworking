//
//  NSBundle+AFAdditions.m
//  Amber
//
//  Created by Keith Duncan on 10/01/2009.
//  Copyright 2009 software. All rights reserved.
//

#import "NSBundle+Additions.h"

#import "NSArray+Additions.h"

@implementation NSBundle (AFAdditions)

- (NSString *)version {
	return [self objectForInfoDictionaryKey:(id)kCFBundleVersionKey];
}

- (NSString *)displayVersion {
	id value = [self objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	if (value == nil) value = [self version];
	return value;
}

- (NSString *)name {
	return [self objectForInfoDictionaryKey:(id)kCFBundleNameKey];
}

- (NSString *)displayName {
	id value = [self objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (value == nil) value = [self name];
	return value;
}

@end

@implementation NSBundle (AFPathAdditions)

- (NSURL *)applicationSupportURL:(NSUInteger)searchDomain {
	NSString *path = [AFSafeObjectAtIndex(NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, searchDomain, YES), 0) stringByAppendingPathComponent:[self name]];
	return [NSURL fileURLWithPath:path];
}

@end
