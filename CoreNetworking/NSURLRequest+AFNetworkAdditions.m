//
//  NSURLRequest+AFNetworkAdditions.m
//  Amber
//
//  Created by Keith Duncan on 14/04/2010.
//  Copyright 2010. All rights reserved.
//

#import "NSURLRequest+AFNetworkAdditions.h"

static NSString * (^URLEncodeString)(NSString *) = ^ NSString * (NSString *string) {
	return NSMakeCollectable(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8));
};

static NSString *const AFHTTPBodyFileLocationKey = @"AFHTTPBodyFileLocation";

@implementation NSURLRequest (AFNetworkAdditions)

- (NSDictionary *)_parametersFromString:(NSString *)string {
	return [NSDictionary dictionaryWithString:string separator:@"=" delimiter:@"&"];
}

- (NSDictionary *)parametersFromQuery {
	NSString *query = [[self URL] query];
	if (query == nil) return nil;
	return [self _parametersFromString:query];
}

- (NSDictionary *)parametersFromBody {
	if (![[self valueForHTTPHeaderField:@"Content-Type"] isEqualToString:@"application/x-www-form-urlencoded"]) return nil;
	
	NSString *bodyString = [[NSString alloc] initWithData:[self HTTPBody] encoding:NSUTF8StringEncoding];
	return [self _parametersFromString:bodyString];
}

- (NSURL *)HTTPBodyFile {
	return [NSURLProtocol propertyForKey:AFHTTPBodyFileLocationKey inRequest:self];
}

@end

@implementation NSMutableURLRequest (AFNetworkAdditions)

@dynamic HTTPBodyFile;

- (void)appendQueryParameters:(NSDictionary *)parameters {
	// Note: this ensures duplicate parameters aren't added
	NSMutableDictionary *allParameters = [NSMutableDictionary dictionary];
	[allParameters addEntriesFromDictionary:[self parametersFromQuery]];
	[allParameters addEntriesFromDictionary:parameters];
	
	
	NSMutableArray *queryParameters = [NSMutableArray arrayWithCapacity:[allParameters count]];
	
	[allParameters enumerateKeysAndObjectsUsingBlock:^ (id key, id obj, BOOL *stop) {
		NSMutableString *parameter = [NSMutableString string];
		[parameter appendString:URLEncodeString(key)];
		[parameter appendString:@"="];
		if (![obj isKindOfClass:[NSNull class]]) [parameter appendString:URLEncodeString(obj)]; 
		
		[queryParameters addObject:parameter];
	}];
	
	NSMutableString *absoluteURLString = [[[self URL] absoluteString] mutableCopy];
	
	NSString *newQuery = [@"?" stringByAppendingString:[queryParameters componentsJoinedByString:@"&"]];
	
	if ([[self URL] query] != nil) {
		NSRange queryRange = [absoluteURLString rangeOfString:[[self URL] query]];
		queryRange.location--; // Note: remove the '?'
		queryRange.length++;
		[absoluteURLString replaceCharactersInRange:queryRange withString:newQuery];
	} else {
		[absoluteURLString appendString:newQuery];
	}
	
	[self setURL:[NSURL URLWithString:absoluteURLString]];
}

- (void)setHTTPBodyFile:(NSURL *)HTTPBodyFile {
	if (HTTPBodyFile != nil) {
		[NSURLProtocol setProperty:[[HTTPBodyFile copy] autorelease] forKey:AFHTTPBodyFileLocationKey inRequest:self];
	} else {
		[NSURLProtocol removePropertyForKey:AFHTTPBodyFileLocationKey inRequest:self];
	}
}

@end
