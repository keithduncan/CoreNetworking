//
//  AFHTTPConstants.m
//  Amber
//
//  Created by Keith Duncan on 19/07/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPMessage.h"

#import "AFNetworkPacketWrite.h"
#import "AFNetworkPacketWriteFromReadStream.h"

#import "NSDictionary+AFNetworkAdditions.h"
#import "NSURLRequest+AFNetworkAdditions.h"

@interface _AFHTTPURLResponse : NSHTTPURLResponse {
 @private
	__strong CFHTTPMessageRef _message;
}

- (id)initWithURL:(NSURL *)URL message:(CFHTTPMessageRef)message;

@property (retain) __strong __attribute__((NSObject)) CFHTTPMessageRef message;

@end

@implementation _AFHTTPURLResponse

@synthesize message=_message;

- (id)initWithURL:(NSURL *)URL message:(CFHTTPMessageRef)message {
	NSString *MIMEType = nil; NSString *textEncodingName = nil;
	NSString *contentType = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentTypeHeader)) autorelease];
	if (contentType != nil) {
		NSRange parameterSeparator = [contentType rangeOfString:@";"];
		if (parameterSeparator.location == NSNotFound) {
			MIMEType = contentType;
		} else {
			MIMEType = [contentType substringToIndex:parameterSeparator.location];
			
			NSMutableDictionary *contentTypeParameters = [NSMutableDictionary dictionaryWithString:[contentType substringFromIndex:(parameterSeparator.location + 1)] separator:@"=" delimiter:@";"];
			[[[contentTypeParameters copy] autorelease] enumerateKeysAndObjectsUsingBlock:^ (id key, id obj, BOOL *stop) {
				[contentTypeParameters removeObjectForKey:key];
				
				key = [[key mutableCopy] autorelease];
				CFStringTrimWhitespace((CFMutableStringRef)key);
				
				obj = [[obj mutableCopy] autorelease];
				CFStringTrimWhitespace((CFMutableStringRef)obj);
				
				[contentTypeParameters setObject:obj forKey:key];
			}];
			textEncodingName = [contentTypeParameters objectForCaseInsensitiveKey:@"charset"];
			
			if ([textEncodingName characterAtIndex:0] == '"' && [textEncodingName characterAtIndex:([textEncodingName length] - 1)] == '"') {
				textEncodingName = [textEncodingName substringWithRange:NSMakeRange(1, [textEncodingName length] - 2)];
			}
		}
	}
	
	NSString *contentLength = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease];
	
	self = [self initWithURL:URL MIMEType:MIMEType expectedContentLength:(contentLength != nil ? [contentLength integerValue] : -1) textEncodingName:textEncodingName];
	if (self == nil) return nil;
	
	_message = (CFHTTPMessageRef)CFMakeCollectable(CFRetain(message));
	
	return self;
}

- (void)dealloc {
	CFRelease(_message);
	
	[super dealloc];
}

- (NSInteger)statusCode {
	return CFHTTPMessageGetResponseStatusCode([self message]);
}

- (NSDictionary *)allHeaderFields {
	return [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields([self message])) autorelease];
}

@end

CFHTTPMessageRef AFHTTPMessageCreateForRequest(NSURLRequest *request) {
	NSCParameterAssert([request HTTPBodyStream] == nil);
	NSCParameterAssert([request HTTPBodyFile] == nil);
	
	CFHTTPMessageRef message = CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)[request HTTPMethod], (CFURLRef)[request URL], kCFHTTPVersion1_1);
	
	for (NSString *currentHeader in [request allHTTPHeaderFields]) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)currentHeader, (CFStringRef)[[request allHTTPHeaderFields] objectForKey:currentHeader]);
	}
	
	if ([request HTTPBody] != nil) {
		CFHTTPMessageSetBody(message, (CFDataRef)[request HTTPBody]);
	}
	
	return message;
}

NSURLRequest *AFHTTPURLRequestForHTTPMessage(CFHTTPMessageRef message) {
	NSURL *messageURL = [NSMakeCollectable(CFHTTPMessageCopyRequestURL(message)) autorelease];
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:messageURL];
	[request setHTTPMethod:[NSMakeCollectable(CFHTTPMessageCopyRequestMethod(message)) autorelease]];
	[request setAllHTTPHeaderFields:[NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(message)) autorelease]];
	[request setHTTPBody:[NSMakeCollectable(CFHTTPMessageCopyBody(message)) autorelease]];
	
	return request;
}

CFHTTPMessageRef AFHTTPMessageCreateForResponse(NSHTTPURLResponse *response) {
	CFHTTPMessageRef message = CFHTTPMessageCreateResponse(kCFAllocatorDefault, [response statusCode], (CFStringRef)[NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], kCFHTTPVersion1_1);
	[[response allHeaderFields] enumerateKeysAndObjectsUsingBlock:^ (id key, id obj, BOOL *stop) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)key, (CFStringRef)obj);
	}];
	return message;
}

NSHTTPURLResponse *AFHTTPURLResponseForHTTPMessage(NSURL *URL, CFHTTPMessageRef message) {
	return [[[_AFHTTPURLResponse alloc] initWithURL:URL message:message] autorelease];
}

void _AFHTTPPrintMessage(CFHTTPMessageRef message) {
	printf("%s", [[[[NSString alloc] initWithData:[NSMakeCollectable(CFHTTPMessageCopySerializedMessage(message)) autorelease] encoding:NSMacOSRomanStringEncoding] autorelease] UTF8String]);
}

void _AFHTTPPrintRequest(NSURLRequest *request) {
	_AFHTTPPrintMessage((CFHTTPMessageRef)[NSMakeCollectable(AFHTTPMessageCreateForRequest((id)request)) autorelease]);
}

void _AFHTTPPrintResponse(NSURLResponse *response) {
	_AFHTTPPrintMessage((CFHTTPMessageRef)[NSMakeCollectable(AFHTTPMessageCreateForResponse((id)response)) autorelease]);
}

AFNetworkPacket <AFNetworkPacketWriting> *AFHTTPConnectionPacketForMessage(CFHTTPMessageRef message) {
	NSData *messageData = [NSMakeCollectable(CFHTTPMessageCopySerializedMessage(message)) autorelease];
	return [[[AFNetworkPacketWrite alloc] initWithData:messageData] autorelease];
}

NSString *const AFHTTPMethodHEAD = @"HEAD";
NSString *const AFHTTPMethodTRACE = @"TRACE";
NSString *const AFHTTPMethodOPTIONS = @"OPTIONS";

NSString *const AFHTTPMethodGET = @"GET";
NSString *const AFHTTPMethodPOST = @"POST";
NSString *const AFHTTPMethodPUT = @"PUT";
NSString *const AFHTTPMethodDELETE = @"DELETE";


NSString *const AFNetworkSchemeHTTP = @"http";
NSString *const AFNetworkSchemeHTTPS = @"https";


NSString *const AFHTTPMessageUserAgentHeader = @"User-Agent";
NSString *const AFHTTPMessageHostHeader = @"Host";

NSString *const AFHTTPMessageConnectionHeader = @"Connection";

NSString *const AFHTTPMessageContentLengthHeader = @"Content-Length";
NSString *const AFHTTPMessageContentTypeHeader = @"Content-Type";
NSString *const AFHTTPMessageContentRangeHeader = @"Content-Range";
NSString *const AFHTTPMessageContentMD5Header = @"Content-MD5";

NSString *const AFHTTPMessageTransferEncodingHeader = @"Transfer-Encoding";

NSString *const AFHTTPMessageAllowHeader = @"Allow";
NSString *const AFHTTPMessageLocationHeader = @"Location";
NSString *const AFHTTPMessageRangeHeader = @"Range";


CFStringRef AFHTTPStatusCodeGetDescription(AFHTTPStatusCode code) {
	switch (code) {
		case AFHTTPStatusCodeContinue:
			return CFSTR("Continue");
			
		case AFHTTPStatusCodeOK:
			return CFSTR("OK");
		case AFHTTPStatusCodePartialContent:
			return CFSTR("Partial Content");
			
		case AFHTTPStatusCodeFound:
			return CFSTR("Found");
		case AFHTTPStatusCodeSeeOther:
			return CFSTR("See Other");
			
		case AFHTTPStatusCodeBadRequest:
			return CFSTR("Bad Request");
		case AFHTTPStatusCodeNotFound:
			return CFSTR("Not Found");
		case AFHTTPStatusCodeNotAllowed:
			return CFSTR("Not Allowed");
		case AFHTTPStatusCodeUpgradeRequired:
			return CFSTR("Upgrade Required");
			
		case AFHTTPStatusCodeServerError:
			return CFSTR("Server Error");
		case AFHTTPStatusCodeNotImplemented:
			return CFSTR("Not Implemented");
	}
	
	[NSException raise:NSInvalidArgumentException format:@"%s, (%ld) is not a known status code", __PRETTY_FUNCTION__, nil];
	return NULL;
}
