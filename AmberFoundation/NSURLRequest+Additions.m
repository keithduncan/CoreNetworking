//
//  NSURLRequest+Additions.m
//  AmberFoundation
//
//  Created by Keith Duncan on 04/10/2010.
//  Copyright 2010 Keith Duncan. All rights reserved.
//

#import "NSURLRequest+Additions.h"

static NSString * (^URLEncodeString)(NSString *) = ^ NSString * (NSString *string) {
	return NSMakeCollectable(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8));
};

@implementation NSURLRequest (TwitterConsoleStreamAdditions)

+ (NSDictionary *)parametersFromString:(NSString *)parameterString {
	NSArray *parameterPairs = [parameterString componentsSeparatedByString:@"&"];
	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:[parameterPairs count]];
	
	for (NSString *currentPair in parameterPairs) {
		NSArray *pairComponents = [currentPair componentsSeparatedByString:@"="];
		
		NSString *key = ([pairComponents count] >= 1 ? [pairComponents objectAtIndex:0] : nil);
		if (key == nil) continue;
		
		NSString *value = ([pairComponents count] >= 2 ? [pairComponents objectAtIndex:1] : [NSNull null]);
		[parameters setObject:value forKey:key];
	}
	
	return parameters;
}

@end

@implementation NSMutableURLRequest (TwitterConsoleStreamAdditions)

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

- (NSDictionary *)parametersFromQuery {
	NSString *query = [[self URL] query];
	if (query == nil) return nil;
	return [NSURLRequest parametersFromString:query];
}

- (NSDictionary *)parametersFromBody {
	if (![[self valueForHTTPHeaderField:@"Content-Type"] isEqualToString:@"application/x-www-form-urlencoded"]) return nil;
	
	NSString *bodyString = [[NSString alloc] initWithData:[self HTTPBody] encoding:NSUTF8StringEncoding];
	return [NSURLRequest parametersFromString:bodyString];
}

@end
