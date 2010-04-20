//
//  AFHTTPTransaction.m
//  Amber
//
//  Created by Keith Duncan on 18/05/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPTransaction.h"

@implementation AFHTTPTransaction

@synthesize requestPackets=_requestPackets, responsePackets=_responsePackets;
@synthesize context=_context;

- (id)initWithRequestPackets:(NSArray *)requestPackets responsePackets:(NSArray *)responsePackets context:(void *)context {
	self = [super init];
	if (self == nil) return nil;
	
	_requestPackets = [requestPackets copy];
	_responsePackets = [responsePackets copy];
	
	_context = context;
	
	return self;
}

- (void)dealloc {
	[_requestPackets release];
	[_responsePackets release];
	
	[super dealloc];
}

@end
