//
//  AFServiceDiscoveryRunLoopSource.m
//  Amber
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008. All rights reserved.
//

#import "AFNetworkServiceSource.h"

#import "AFNetworkSchedule.h"

@interface AFNetworkServiceSource ()
@property (retain, nonatomic) AFNetworkSchedule *schedule;
@end

@implementation AFNetworkServiceSource

@synthesize service=_service;
@synthesize schedule=_schedule;

static void _AFNetworkServiceRunLoopSourceEnableCallbacks(CFFileDescriptorRef fileDescriptor) {
	CFFileDescriptorEnableCallBacks(fileDescriptor, kCFFileDescriptorReadCallBack);
}

static void	_AFNetworkServiceRunLoopSource(CFFileDescriptorRef fileDescriptor, CFOptionFlags callBackTypes, void *info) {
	if ((callBackTypes & kCFFileDescriptorReadCallBack) != kCFFileDescriptorReadCallBack) return;
	
	AFNetworkServiceSource *self = info;
	
	__unused DNSServiceErrorType error = DNSServiceProcessResult(self->_service);
	
	_AFNetworkServiceRunLoopSourceEnableCallbacks(fileDescriptor);
}

/*!
	\brief
	Create and schedule a dispatch source for the mDNSResponder socket held by the service argument.
	
	\param service
	Must not be NULL
	
	\param queue
	Must not be NULL
 */
static dispatch_source_t AFNetworkServiceCreateQueueSource(DNSServiceRef service, dispatch_queue_t queue) {
	dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, DNSServiceRefSockFD(service), 0, queue);
	
	dispatch_source_set_event_handler(source, ^ {
		DNSServiceProcessResult(service);
	});
	
	return source;
}

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
	
	CFFileDescriptorRef *fileDescriptorRef = &_sources._runLoop._fileDescriptor;
	if (*fileDescriptorRef != NULL) {
		CFRelease(*fileDescriptorRef);
		CFRelease(_sources._runLoop._source);
	}
	
	if (_sources._dispatchSource != NULL) {
		dispatch_release(_sources._dispatchSource);
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
	
	if (schedule->_runLoop != nil) {
		NSRunLoop *runLoop = schedule->_runLoop;
		
		CFFileDescriptorContext context = {
			.info = self,
		};
		CFFileDescriptorRef newFileDescriptor = (CFFileDescriptorRef)CFMakeCollectable(CFFileDescriptorCreate(kCFAllocatorDefault, DNSServiceRefSockFD(_service), false, _AFNetworkServiceRunLoopSource, &context));
		_AFNetworkServiceRunLoopSourceEnableCallbacks(newFileDescriptor);
		_sources._runLoop._fileDescriptor = newFileDescriptor;
		
		CFRunLoopSourceRef newSource = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, newFileDescriptor, 0);
		_sources._runLoop._source = newSource;
		
		CFRunLoopAddSource([runLoop getCFRunLoop], newSource, (CFStringRef)schedule->_runLoopMode);
	}
	else if (schedule->_dispatchQueue != NULL) {
		dispatch_queue_t dispatchQueue = schedule->_dispatchQueue;
		
		dispatch_source_t newSource = AFNetworkServiceCreateQueueSource(self.service, dispatchQueue);
		_sources._dispatchSource = newSource;
		
		dispatch_resume(newSource);
	}
	else {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"unsupported schedule environment, cannot resume service source" userInfo:nil];
	}
}

- (void)invalidate {
	CFRunLoopSourceRef *sourceRef = &_sources._runLoop._source;
	if (*sourceRef != NULL) {
		CFRunLoopSourceInvalidate(*sourceRef);
	}
	
	if (_sources._dispatchSource != NULL) {
		dispatch_source_cancel(_sources._dispatchSource);
	}
}

- (BOOL)isValid {
	CFRunLoopSourceRef *sourceRef = &_sources._runLoop._source;
	if (*sourceRef != NULL) {
		return CFRunLoopSourceIsValid(*sourceRef);
	}
	
	if (_sources._dispatchSource != NULL) {
		return (dispatch_source_testcancel(_sources._dispatchSource) == 0);
	}
	
	return NO;
}

@end
