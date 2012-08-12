//
//  AFNetworkSchedulerProxy.m
//  CoreNetworking
//
//  Created by Keith Duncan on 10/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import "AFNetworkSchedulerProxy.h"

#import "AFNetworkLayer.h"

@implementation AFNetworkSchedulerProxy

- (id)init {
	_invocationsLock = [[NSLock alloc] init];
	_invocations = [[NSMutableSet alloc] init];
	
	return self;
}

- (void)dealloc {
	[_invocationsLock release];
	[_invocations release];
	
	[super dealloc];
}

- (void)scheduleNetworkLayer:(id <AFNetworkSchedulable>)networkLayer {
	[_invocationsLock lock];
	
	for (NSInvocation *currentScheduleInvocation in _invocations) {
		[currentScheduleInvocation invokeWithTarget:networkLayer];
	}
	
	[_invocationsLock unlock];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return [AFNetworkLayer instanceMethodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	[_invocationsLock lock];
	
	[_invocations addObject:invocation];
	
	[_invocationsLock unlock];
}

@end
