//
//  NSFileManager+Verification.m
//  Amber
//
//  Created by Keith Duncan on 06/12/2007.
//  Copyright 2007 Keith Duncan. All rights reserved.
//

#import "NSFileManager+Additions.h"

#import <CommonCrypto/CommonDigest.h>

#import "NSData+Additions.h"

@implementation NSFileManager (AFVerificationAdditions)

- (BOOL)validatePath:(NSString *)path withMD5Hash:(NSString *)hash {
	return [self validateURL:[NSURL fileURLWithPath:path] withMD5Hash:[NSData dataWithHexString:hash]];
}

- (BOOL)validateURL:(NSURL *)location withMD5Hash:(NSData *)hash {
	NSData *data = [NSData dataWithContentsOfURL:location];
	if (data == nil) return NO;
	
	return [hash isEqualToData:[data MD5Hash]];
}

@end
