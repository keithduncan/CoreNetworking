//
//  AFHTTPTransaction.m
//  Amber
//
//  Created by Keith Duncan on 18/05/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFHTTPTransaction.h"

@implementation AFHTTPTransaction

@synthesize emptyRequest=_emptyRequest;
@synthesize request=_request, response=_response;

- (id)initWithRequest:(CFHTTPMessageRef)request {
	self = [super init];
	if (self == nil) return nil;
	
	if (request == NULL) {
		_emptyRequest = YES;
		_request = (CFHTTPMessageRef)NSMakeCollectable(CFHTTPMessageCreateEmpty(kCFAllocatorDefault, true));
	} else {
		_request = (CFHTTPMessageRef)NSMakeCollectable(CFRetain(request));
		_response = (CFHTTPMessageRef)NSMakeCollectable(CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false));
	}
	
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

@end
