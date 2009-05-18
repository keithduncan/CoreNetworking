//
//  NSBundle+AFAdditions.m
//  Amber
//
//  Created by Keith Duncan on 10/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "NSBundle+Additions.h"

#import "NSArray+Additions.h"

NSString *const AFCompanyNameKey = @"AFCompanyName";

@implementation NSBundle (AFAdditions)

- (NSString *)version {
	return [self objectForInfoDictionaryKey:@"CFBundleVersion"];
}

- (NSString *)displayVersion {
	return [self objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (NSString *)name {
	return [self objectForInfoDictionaryKey:@"CFBundleName"];
}

- (NSString *)displayName {
	return [self objectForInfoDictionaryKey:@"CFBundleDisplayName"];
}

- (NSString *)companyName {
	return [self objectForInfoDictionaryKey:AFCompanyNameKey];
}

@end

@implementation NSBundle (AFPathAdditions)

- (NSString *)applicationSupportPath:(NSUInteger)searchDomain {
	return [[self applicationSupportURL:searchDomain] path];
}

- (NSURL *)applicationSupportURL:(NSUInteger)searchDomain {
	NSString *path = [AFSafeObjectAtIndex(NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, searchDomain, YES), 0) stringByAppendingPathComponent:[self name]];
	return [NSURL fileURLWithPath:path];
}

@end
