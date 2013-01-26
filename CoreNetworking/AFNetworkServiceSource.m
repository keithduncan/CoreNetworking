//
//  AFServiceDiscoveryRunLoopSource.m
//  Amber
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008. All rights reserved.
//

#import "AFNetworkServiceSource.h"

#import "AFNetworkSchedule.h"
#import "AFNetworkSchedule+AFNetworkPrivate.h"

@interface AFNetworkServiceSource ()
@property (retain, nonatomic) AFNetworkSchedule *schedule;
@end

@implementation AFNetworkServiceSource

@synthesize service=_service;
@synthesize schedule=_schedule;

- (id)initWithService:(DNSServiceRef)service {
	NSParameterAssert(service != NULL);
	
	self = [self init];
	if (self == nil) return nil;
	
	_service = service;
	
	return self;
}

- (void)dealloc {
	[_schedule release];
	
	[self _cleanup];
	
	[super dealloc];
}

- (void)_cleanup {
	[self invalidate];
	
	if (_dispatchSource != NULL) {
		dispatch_release(_dispatchSource);
	}
}

- (BOOL)_isScheduled {
	return (self.schedule != nil);
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(![self _isScheduled]);
	
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInRunLoop:runLoop forMode:mode];
	self.schedule = newSchedule;
}

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	NSParameterAssert(![self _isScheduled]);
	
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInQueue:queue];
	self.schedule = newSchedule;
}

- (void)resume {
	AFNetworkSchedule *schedule = self.schedule;
	NSParameterAssert(schedule != nil);
	
	NSParameterAssert(![self isValid]);
	
	DNSServiceRef service = self.service;
	dispatch_source_t newSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, DNSServiceRefSockFD(service), 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
	dispatch_source_set_event_handler(newSource, ^ {
		[schedule _performBlock:^ {
			DNSServiceProcessResult(service);
		}];
	});
	_dispatchSource = newSource;
	
	dispatch_resume(newSource);
}

- (void)invalidate {
	if (_dispatchSource != NULL) {
		dispatch_source_cancel(_dispatchSource);
	}
}

- (BOOL)isValid {
	if (_dispatchSource != NULL) {
		return (dispatch_source_testcancel(_dispatchSource) == 0);
	}
	
	return NO;
}

@end
