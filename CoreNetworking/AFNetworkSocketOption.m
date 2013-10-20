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

@property (readwrite, copy, nonatomic) NSData *data;
@end

@implementation AFNetworkSocketOption

+ (instancetype)optionWithLevel:(int)level option:(int)option value:(NSValue *)value
{
	char const *type = [value objCType];
	if (strcmp(type, @encode(int)) == 0) {
		int val;
		[value getValue:&val];
		return [self optionWithLevel:level option:option data:[NSData dataWithBytes:&val length:sizeof(val)]];
	}
	
	@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s is not a supported value type", type] userInfo:nil];
	return nil;
}

+ (instancetype)optionWithLevel:(int)level option:(int)option data:(NSData *)data
{
	return [[[self alloc] initWithLevel:level option:option data:data] autorelease];
}

- (id)initWithLevel:(int)level option:(int)option data:(NSData *)data
{
	self = [self init];
	if (self == nil) {
		return nil;
	}
	
	_level = level;
	_option = option;
	
	_data = [data copy];
	
	return self;
}

- (void)dealloc
{
	[_data release];
	
	[super dealloc];
}

@end
