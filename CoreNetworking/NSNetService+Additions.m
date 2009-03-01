//
//  NSNetService+Additions.m
//  Bonjour
//
//  Created by Keith Duncan on 30/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "NSNetService+Additions.h"

#import <dns_sd.h>

@implementation NSNetService (Additions)

- (NSString *)fullName {
	char *fullNameStr = (char *)malloc(kDNSServiceMaxDomainName); // Note: this size includes the NULL byte at the end
	
	DNSServiceErrorType error = kDNSServiceErr_NoError;
	error = DNSServiceConstructFullName(fullNameStr, [[self name] UTF8String], [[self type] UTF8String], [[self domain] UTF8String]);
	
	if (error != kDNSServiceErr_NoError) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, could not form a full DNS name.", __PRETTY_FUNCTION__, NSStringFromClass([self class]), _cmd, nil];
		return nil;
	}
	
	NSString *fullName = [NSString stringWithUTF8String:fullNameStr];
	
	fullName = [fullName stringByReplacingOccurrencesOfString:@"\032" withString:@" "];
#warning this is a mild hack
	
	free(fullNameStr);
	
	return fullName;
}

@end
