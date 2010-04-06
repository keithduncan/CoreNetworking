//
//  AFTargetProxy.m
//  Amber
//
//  Created by Keith Duncan on 07/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFTargetProxy.h"

@implementation AFTargetProxy

- (id)initWithTarget:(id)target keyPath:(NSString *)keyPath {
	_target = [target retain];
	_keyPath = [keyPath copy];
	
	return self;
}

- (void)dealloc {
	[_target release];
	[_keyPath release];
	
	[super dealloc];
}

- (id)forwardingTargetForSelector:(SEL)selector {
	return [_target valueForKeyPath:_keyPath];
}

@end
