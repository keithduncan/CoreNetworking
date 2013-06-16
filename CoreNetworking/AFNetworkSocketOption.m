//
//  AFNetworkSocketOption.m
//  CoreNetworking
//
//  Created by Keith Duncan on 27/05/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import "AFNetworkSocketOption.h"

@interface AFNetworkSocketOption ()
@property (readwrite, assign, nonatomic) int level;
@property (readwrite, assign, nonatomic) int option;

@property (readwrite, copy, nonatomic) NSData *value;
@end

@implementation AFNetworkSocketOption

+ (instancetype)optionWithLevel:(int)level option:(int)option value:(NSData *)value
{
	return [[[self alloc] initWithLevel:level option:option value:value] autorelease];
}

- (id)initWithLevel:(int)level option:(int)option value:(NSData *)value
{
	self = [self init];
	if (self == nil) {
		return nil;
	}
	
	_level = level;
	_option = option;
	
	_value = [value copy];
	
	return self;
}

- (void)dealloc
{
	[_value release];
	
	[super dealloc];
}

@end
