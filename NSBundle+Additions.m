//
//  NSBundle+Additions.m
//  dawn
//
//  Created by Keith Duncan on 16/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSBundle+Additions.h"

@implementation NSBundle (AFAdditions)

static NSImage *AFCacheImageFromBundle(NSBundle *bundle, NSString *key) {
	NSImage *image = nil;
	NSString *name = [bundle objectForInfoDictionaryKey:key];
	
	image = [NSImage imageNamed:name];
	if (image != nil) return image;
	
	image = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:name]];
	[image setName:name];
	
	return image;
}

- (NSImage *)icon {
	return AFCacheImageFromBundle(self, @"CFBundleIconFile");
}

- (NSImage *)alertIcon {
	return AFCacheImageFromBundle(self, AFAlertIconFileKey);
}

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

NSString *const AFAlertIconFileKey = @"AFAlertIconFile";
NSString *const AFCompanyNameKey = @"AFCompanyName";
