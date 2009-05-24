//
//  AFHTTPTransaction.m
//  Amber
//
//  Created by Keith Duncan on 18/05/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFHTTPTransaction.h"

@implementation AFHTTPTransaction

@synthesize request=_request, response=_response;

- (id)initWithRequest:(CFHTTPMessageRef)request {
	self = [super init];
	if (self == nil) return nil;
	
	_request = (CFHTTPMessageRef)NSMakeCollectable(CFRetain(request));
	_response = (CFHTTPMessageRef)NSMakeCollectable(CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false));
	
	return self;
}

- (void)dealloc {
	if (_request != NULL) {
		CFRelease(_request);
		_request = NULL;
	}
	
	if (_response != NULL) {
		CFRelease(_response);
		_response = NULL;
	}
	
	[super dealloc];
}

- (NSInteger)responseBodyLength {
	if (!CFHTTPMessageIsHeaderComplete(self.response)) {
		return -1;
	}
	
	NSString *contentLengthHeaderValue = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(self.response, CFSTR("Content-Length"))) autorelease];
	
	NSInteger contentLength = 0;
	[[NSScanner scannerWithString:contentLengthHeaderValue] scanInteger:&contentLength];
	
	return contentLength;
}

@end
