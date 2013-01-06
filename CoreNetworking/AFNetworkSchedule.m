//
//  AFNetworkEnvironment.m
//  CoreNetworking
//
//  Created by Keith Duncan on 05/01/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import "AFNetworkSchedule.h"

@implementation AFNetworkSchedule

- (void)dealloc {
	[_runLoop release];
	[_runLoopMode release];
	
	if (_dispatchQueue != NULL) {
		dispatch_release(_dispatchQueue);
	}
	
	[super dealloc];
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(runLoop != nil);
	NSParameterAssert(mode != nil);
	
	NSParameterAssert(![self _isScheduled]);
	
	_runLoop = [runLoop retain];
	_runLoopMode = [mode copy];
}

- (void)scheduleInQueue:(dispatch_queue_t)dispatchQueue {
	NSParameterAssert(![self _isScheduled]);
	
	dispatch_retain(dispatchQueue);
	_dispatchQueue = dispatchQueue;
}

- (BOOL)_isScheduled {
	return ((_runLoop != NULL) || (_dispatchQueue != NULL));
}

@end
