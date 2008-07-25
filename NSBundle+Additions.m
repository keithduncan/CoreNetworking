//
//  NSBundle+Additions.m
//  dawn
//
//  Created by Keith Duncan on 16/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSBundle+Additions.h"

#import <objc/runtime.h>

@implementation NSBundle (AFAdditions)

NSImage *AFCacheImageFromBundle(NSBundle *bundle, NSString *name) {
	NSImage *bundleImage = nil;
	NSString *imageName = [bundle objectForInfoDictionaryKey:name];
	
	bundleImage = [NSImage imageNamed:imageName];
	if (bundleImage != nil) return bundleImage;
	
	bundleImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:imageName]];
	[bundleImage setName:imageName];
	
	return bundleImage;
}

- (NSImage *)icon {
	return AFCacheImageFromBundle(self, @"CFBundleIconFile");
}

- (NSImage *)alertImage {
	return AFCacheImageFromBundle(self, AFAlertImageNameKey);
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

- (NSString *)companySite {
	return [self objectForInfoDictionaryKey:AFRootCompanySiteURLKey];
}

@end

@implementation NSBundle (AFPathAdditions)

- (NSString *)applicationSupportPath:(NSUInteger)domain {
	return [AFSafeObjectAtIndex(NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, domain, YES), 0) stringByAppendingPathComponent:[self name]];
}

@end

NSString *const AFAlertImageNameKey = @"AFAlertImageName";
NSString *const AFCompanyNameKey = @"AFCompanyName";
NSString *const AFRootCompanySiteURLKey = @"AFRootCompanySiteURL";
