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
@synthesize completionBlock=_completionBlock;

- (id)initWithRequestPackets:(NSArray *)requestPackets responsePackets:(NSArray *)responsePackets {
	self = [super init];
	if (self == nil) return nil;
	
	_requestPackets = [requestPackets copy];
	_responsePackets = [responsePackets copy];
	
	return self;
}

- (void)dealloc {
	[_requestPackets release];
	[_responsePackets release];
	
	[_completionBlock release];
	
	[super dealloc];
}

@end
