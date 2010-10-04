//
//  AFHTTPConstants.m
//  Amber
//
//  Created by Keith Duncan on 19/07/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPMessage.h"

#import "AFPacketWrite.h"
#import "AFPacketWriteFromReadStream.h"
#import "NSURLRequest+AFHTTPAdditions.h"

CFHTTPMessageRef AFHTTPMessageCreateForRequest(NSURLRequest *request) {
	NSCParameterAssert([request HTTPBodyStream] == nil);
	NSCParameterAssert([request HTTPBodyFile] == nil);
	
	CFHTTPMessageRef message = CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)[request HTTPMethod], (CFURLRef)[request URL], kCFHTTPVersion1_1);
	
	for (NSString *currentHeader in [request allHTTPHeaderFields])
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)currentHeader, (CFStringRef)[[request allHTTPHeaderFields] objectForKey:currentHeader]);
	
	CFHTTPMessageSetBody(message, (CFDataRef)[request HTTPBody]);
	
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
	CFHTTPMessageRef message = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, [response statusCode], (CFStringRef)[NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]], kCFHTTPVersion1_1)) autorelease];
	[[response allHeaderFields] enumerateKeysAndObjectsUsingBlock:^ (id key, id obj, BOOL *stop) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)key, (CFStringRef)obj);
	}];
	return message;
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

AFPacket <AFPacketWriting> *AFHTTPConnectionPacketForMessage(CFHTTPMessageRef message) {
	NSData *messageData = [NSMakeCollectable(CFHTTPMessageCopySerializedMessage(message)) autorelease];
	return [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:messageData] autorelease];
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
NSString *const AFHTTPMessageContentTransferEncodingHeader = @"Content-Transfer-Encoding";

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
