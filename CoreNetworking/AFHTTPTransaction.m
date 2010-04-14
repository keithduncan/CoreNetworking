//
//  AFHTTPTransaction.m
//  Amber
//
//  Created by Keith Duncan on 18/05/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPTransaction.h"

@implementation AFHTTPTransaction

@synthesize requestPackets=_requestPackets, response=_response;

- (id)initWithRequestPackets:(NSArray *)requestPackets {
	self = [super init];
	if (self == nil) return nil;
	
	_requestPackets = [requestPackets copy];
	
	_response = (CFHTTPMessageRef)NSMakeCollectable(CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false));
	
	return self;
}

- (void)dealloc {
	[_requestPackets release];
	
	if (_response != NULL) {
		CFRelease(_response);
		_response = NULL;
	}
	
	[super dealloc];
}

@end
