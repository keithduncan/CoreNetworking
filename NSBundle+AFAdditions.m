//
//  NSBundle+AFAdditions.m
//  Amber
//
//  Created by Keith Duncan on 10/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "NSBundle+AFAdditions.h"

#import "AFCollection.h"

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

- (NSString *)applicationSupportPath:(NSUInteger)domain {
	return [AFSafeObjectAtIndex(NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, domain, YES), 0) stringByAppendingPathComponent:[self name]];
}

@end
