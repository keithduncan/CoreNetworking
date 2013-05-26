//
//  AFNetworkSocketRequest.m
//  CoreNetworking
//
//  Created by Keith Duncan on 26/05/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import "AFNetworkSocketRequest.h"

@interface AFNetworkSocketRequest ()
@property (readwrite, assign, nonatomic) AFNetworkSocketSignature socketSignature;
@property (readwrite, copy, nonatomic) NSData *socketAddress;
@end

@implementation AFNetworkSocketRequest

- (id)initWithSocketSignature:(AFNetworkSocketSignature)socketSignature socketAddress:(NSData *)socketAddress
{
	self = [self init];
	if (self == nil) {
		return nil;
	}
	
	_socketSignature = socketSignature;
	_socketAddress = [socketAddress copy];
	
	return self;
}

- (void)dealloc
{
	[_socketAddress release];
	
	[super dealloc];
}

@end
