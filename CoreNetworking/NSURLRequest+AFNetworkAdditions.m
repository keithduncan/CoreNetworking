//
//  NSURLRequest+AFNetworkAdditions.m
//  Amber
//
//  Created by Keith Duncan on 14/04/2010.
//  Copyright 2010. All rights reserved.
//

#import "NSURLRequest+AFNetworkAdditions.h"

static NSString *const AFHTTPBodyFileLocationKey = @"AFHTTPBodyFileLocation";

@implementation NSURLRequest (AFNetworkAdditions)

- (NSURL *)HTTPBodyFile {
	return [NSURLProtocol propertyForKey:AFHTTPBodyFileLocationKey inRequest:self];
}

@end

@implementation NSMutableURLRequest (AFNetworkAdditions)

@dynamic HTTPBodyFile;

- (void)setHTTPBodyFile:(NSURL *)HTTPBodyFile {
	if (HTTPBodyFile != nil) {
		[NSURLProtocol setProperty:[[HTTPBodyFile copy] autorelease] forKey:AFHTTPBodyFileLocationKey inRequest:self];
	}
	else {
		[NSURLProtocol removePropertyForKey:AFHTTPBodyFileLocationKey inRequest:self];
	}
}

@end
