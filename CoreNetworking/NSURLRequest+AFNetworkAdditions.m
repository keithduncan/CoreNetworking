//
//  NSURLRequest+AFNetworkAdditions.m
//  Amber
//
//  Created by Keith Duncan on 14/04/2010.
//  Copyright 2010. All rights reserved.
//

#import "NSURLRequest+AFNetworkAdditions.h"

#import "AFHTTPMessageMediaType.h"

#warning these methods should be split out into an AFNetworkURLRequest object and be transformable into an NSURLRequest object

static NSString * (^URLEncodeString)(NSString *) = ^ NSString * (NSString *string) {
	if (string == nil) {
		return nil;
	}
	return [NSMakeCollectable(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8)) autorelease];
};

static NSString * (^URLDecodeString)(NSString *) = ^ NSString * (NSString *string) {
	if (string == nil) {
		return nil;
	}
	return [NSMakeCollectable(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8)) autorelease];
};

static NSString *const AFHTTPBodyFileLocationKey = @"AFHTTPBodyFileLocation";

@implementation NSURLRequest (AFNetworkAdditions)

- (NSDictionary *)_parametersFromString:(NSString *)string {
	NSString *delimiter = @"=", *separator = @"&";
	
	NSArray *parameterPairs = [string componentsSeparatedByString:delimiter];
	
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:[parameterPairs count]];
	
	for (NSString *currentPair in parameterPairs) {
		NSArray *pairComponents = [currentPair componentsSeparatedByString:separator];
		
		NSString *key = ([pairComponents count] >= 1 ? [pairComponents objectAtIndex:0] : nil);
		key = URLDecodeString(key);
		if (key == nil) {
			continue;
		}
		
		id value = nil;
		if ([pairComponents count] >= 2) {
			value = [pairComponents objectAtIndex:1];
			value = URLDecodeString(value);
		}
		else {
			value = [NSNull null];
		}
		
		if (value == nil) {
			continue;
		}
		
		[parameters setObject:value forKey:key];
	}
	
	return parameters;
}

- (NSDictionary *)parametersFromQuery {
	NSString *query = [[self URL] query];
	if (query == nil) {
		return nil;
	}
	return [self _parametersFromString:query];
}

- (NSDictionary *)parametersFromBody {
	NSString *contentType = [self valueForHTTPHeaderField:@"Content-Type"];
	AFHTTPMessageMediaType *mediaType = AFHTTPMessageParseContentTypeHeader(contentType);
	if (mediaType == nil) {
		return nil;
	}
	
	if ([[mediaType type] caseInsensitiveCompare:@"application/x-www-form-urlencoded"] != NSOrderedSame) {
		return nil;
	}
	
	NSStringEncoding encoding = 0;
	do {
		NSString *textEncodingName = [[mediaType parameters] objectForKey:@"charset"];
		if (textEncodingName == nil) {
			break;
		}
		
		CFStringEncoding stringEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)textEncodingName);
		if (stringEncoding == kCFStringEncodingInvalidId) {
			break;
		}
		
		encoding = CFStringConvertEncodingToNSStringEncoding(stringEncoding);
	} while (0);
	
	if (encoding == 0) {
		encoding = NSISOLatin1StringEncoding;
	}
	
	NSString *bodyString = [[[NSString alloc] initWithData:[self HTTPBody] encoding:encoding] autorelease];
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
		if ([obj isKindOfClass:[NSString class]]) {
			[parameter appendString:URLEncodeString(obj)];
		}
		
		[queryParameters addObject:parameter];
	}];
	
	NSMutableString *absoluteURLString = [[[[self URL] absoluteString] mutableCopy] autorelease];
	
	NSString *newQuery = [@"?" stringByAppendingString:[queryParameters componentsJoinedByString:@"&"]];
	
	if ([[self URL] query] != nil) {
		NSRange queryRange = [absoluteURLString rangeOfString:[[self URL] query]];
		queryRange.location--; // Note: remove the '?'
		queryRange.length++;
		[absoluteURLString replaceCharactersInRange:queryRange withString:newQuery];
	}
	else {
		[absoluteURLString appendString:newQuery];
	}
	
	[self setURL:[NSURL URLWithString:absoluteURLString]];
}

- (void)setHTTPBodyFile:(NSURL *)HTTPBodyFile {
	if (HTTPBodyFile != nil) {
		[NSURLProtocol setProperty:[[HTTPBodyFile copy] autorelease] forKey:AFHTTPBodyFileLocationKey inRequest:self];
	}
	else {
		[NSURLProtocol removePropertyForKey:AFHTTPBodyFileLocationKey inRequest:self];
	}
}

@end
