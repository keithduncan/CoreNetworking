//
//  AFNetworkDatagram.m
//  CoreNetworking
//
//  Created by Keith Duncan on 26/05/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import "AFNetworkDatagram.h"

@interface AFNetworkDatagram ()
@property (readwrite, copy, nonatomic) NSData *senderAddress;
@property (readwrite, copy, nonatomic) NSData *data;
@end

@implementation AFNetworkDatagram

- (id)initWithSenderAddress:(NSData *)senderAddress data:(NSData *)data
{
	self = [self init];
	if (self == nil) {
		return nil;
	}
	
	_senderAddress = [senderAddress copy];
	_data = [data copy];
	
	return self;
}

- (void)dealloc
{
	[_senderAddress release];
	[_data release];
	
	[super dealloc];
}

@end
