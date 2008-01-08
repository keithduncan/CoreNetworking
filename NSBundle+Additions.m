//
//  NSBundle+Additions.m
//  dawn
//
//  Created by Keith Duncan on 16/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSBundle+Additions.h"

@implementation NSBundle (Additions)

- (NSImage *)bundleImage {
	NSImage *bundleImage = nil;
	NSString *imageName = [self objectForInfoDictionaryKey:@"CFBundleIconFile"];
	
	bundleImage = [NSImage imageNamed:imageName];
	if (bundleImage != nil) return bundleImage;
	
	bundleImage = [[NSImage alloc] initWithContentsOfFile:[self pathForImageResource:imageName]];
	[bundleImage setName:imageName];
	
	return bundleImage;
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

@end
