//
//  AFServiceDiscoveryRunLoopSource.m
//  Amber
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008. All rights reserved.
//

/*
	ServiceController was taken from Apple's DNSServiceBrowser.m
 */

/*
	Adapted from Adium implementation, improved and simplified,
	Modified to conform to a run loop source like API.
 */

#import "AFNetworkServiceSource.h"

@implementation AFNetworkServiceSource

@synthesize service=_service;

static void _AFNetworkServiceRunLoopSourceEnableCallbacks(CFFileDescriptorRef fileDescriptor) {
	CFFileDescriptorEnableCallBacks(fileDescriptor, kCFFileDescriptorReadCallBack);
}

static void	_AFNetworkServiceRunLoopSource(CFFileDescriptorRef fileDescriptor, CFOptionFlags callBackTypes, void *info) {
	if ((callBackTypes & kCFFileDescriptorReadCallBack) != kCFFileDescriptorReadCallBack) return;
	
	AFNetworkServiceSource *self = info;
	
	DNSServiceErrorType error __attribute__((unused)) = DNSServiceProcessResult(self->_service);
	
	_AFNetworkServiceRunLoopSourceEnableCallbacks(fileDescriptor);
}

- (id)initWithService:(DNSServiceRef)service {
	NSParameterAssert(service != NULL);
	
	self = [self init];
	if (self == nil) return nil;
	
	_service = service;
	
	CFFileDescriptorContext context = {
		.info = self,
	};
	_fileDescriptor = (CFFileDescriptorRef)CFMakeCollectable(CFFileDescriptorCreate(kCFAllocatorDefault, DNSServiceRefSockFD(_service), false, _AFNetworkServiceRunLoopSource, &context));
	_AFNetworkServiceRunLoopSourceEnableCallbacks(_fileDescriptor);
	
	return self;
}

- (void)dealloc {
	CFRelease(_fileDescriptor);
	
	[self invalidate];
	
	if (_sources._runLoopSource != NULL) {
		CFRelease(_sources._runLoopSource);
		_sources._runLoopSource = NULL;
	}
	
#if defined(DISPATCH_API_VERSION)
	if (_sources._dispatchSource != NULL) {
		dispatch_release(_sources._dispatchSource);
		_sources._dispatchSource = NULL;
	}
#endif
	
	[super dealloc];
}

- (void)finalize {
	[self invalidate];
	
#if defined(DISPATCH_API_VERSION)
	if (_sources._dispatchSource != NULL) {
		dispatch_release(_sources._dispatchSource);
		_sources._dispatchSource = NULL;
	}
#endif
	
	[super finalize];
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(_sources._dispatchSource == NULL);
	
	if (_sources._runLoopSource == NULL) {
		_sources._runLoopSource = (CFRunLoopSourceRef)CFMakeCollectable(CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, _fileDescriptor, 0));
	}
	
	CFRunLoopAddSource([runLoop getCFRunLoop], (CFRunLoopSourceRef)_sources._runLoopSource, (CFStringRef)mode);
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(_sources._runLoopSource != NULL);
	
	CFRunLoopRemoveSource([runLoop getCFRunLoop], (CFRunLoopSourceRef)_sources._runLoopSource, (CFStringRef)mode);
}

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	NSParameterAssert(_sources._runLoopSource == NULL);
	
	if (queue != NULL) {
		if (_sources._dispatchSource == NULL) {
			_sources._dispatchSource = AFNetworkServiceCreateQueueSource(self.service, queue);
			dispatch_resume(_sources._dispatchSource);
			return;
		}
		
		dispatch_set_target_queue(_sources._dispatchSource, queue);
		return;
	}
	
	if (_sources._dispatchSource != NULL) {
		dispatch_source_cancel(_sources._dispatchSource);
		dispatch_release(_sources._dispatchSource);
		_sources._dispatchSource = NULL;
	}
}

#endif

- (void)invalidate {
	if (_sources._runLoopSource != NULL) {
		CFRunLoopSourceInvalidate((CFRunLoopSourceRef)_sources._runLoopSource);
	}
	
#if defined(DISPATCH_API_VERSION)
	if (_sources._dispatchSource != NULL) {
		dispatch_source_cancel(_sources._dispatchSource);
	}
#endif
}

- (BOOL)isValid {
	if (_sources._runLoopSource != NULL) {
		return CFRunLoopSourceIsValid((CFRunLoopSourceRef)_sources._runLoopSource);
	}
	
#if defined(DISPATCH_API_VERSION)
	if (_sources._dispatchSource != NULL) {
		return (dispatch_source_testcancel(_sources._dispatchSource) == 0);
	}
#endif
	
	return NO;
}

@end

#if defined(DISPATCH_API_VERSION)

dispatch_source_t AFNetworkServiceCreateQueueSource(DNSServiceRef service, dispatch_queue_t queue) {
	dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, DNSServiceRefSockFD(service), 0, queue);
	
	dispatch_source_set_event_handler(source, ^ {
		DNSServiceProcessResult(service);
	});
	
	return source;
}

#endif
