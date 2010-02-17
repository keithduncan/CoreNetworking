//
//  AFServiceDiscoveryRunLoopSource.m
//  Amber
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

/*
	ServiceController was taken from Apple's DNSServiceBrowser.m
 */

/*
	Adapted from Adium implementation, improved and simplified,
	Modified to conform to a run loop source like API,
	by Keith Duncan
 */

#import "AFServiceDiscoveryRunLoopSource.h"

@implementation AFServiceDiscoveryRunLoopSource

@synthesize service=_service;

static void	AFServiceDiscoveryProcessResult(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
	if (type != kCFSocketReadCallBack) return;
	AFServiceDiscoveryRunLoopSource *self = info;
	
	DNSServiceErrorType error = kDNSServiceErr_NoError;
	error = DNSServiceProcessResult(self->_service);
	(void)error; // Note: keep clang happy
}

- (id)initWithService:(DNSServiceRef)service {
	self = [self init];
	if (self == nil) return nil;
	
	_service = service;
	
	CFSocketContext context = {0};
	context.info = self;
	
	_socket = (CFSocketRef)NSMakeCollectable(CFSocketCreateWithNative(kCFAllocatorDefault, DNSServiceRefSockFD(_service), kCFSocketReadCallBack, AFServiceDiscoveryProcessResult, &context));
	CFSocketSetSocketFlags(_socket, (CFOptionFlags)0); // Note: don't close the underlying socket
	
	_source = (CFRunLoopSourceRef)NSMakeCollectable(CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, (CFIndex)0));
	
	return self;
}

- (void)dealloc {
	CFRelease(_socket);
	CFRelease(_source);
	
	[super dealloc];
}

- (void)scheduleInRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode {
	CFRunLoopAddSource([loop getCFRunLoop], _source, (CFStringRef)mode);
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode {
	CFRunLoopRemoveSource([loop getCFRunLoop], _source, (CFStringRef)mode);
}

- (void)invalidate {
	CFSocketInvalidate(_socket);
}

@end

#if defined(DISPATCH_API_VERSION)

extern void AFServiceDiscoveryScheduleQueueSource(DNSServiceRef service, dispatch_queue_t queue) {
	dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, DNSServiceRefSockFD(service), 0, queue);
	
	dispatch_source_set_event_handler(source, ^ {
		DNSServiceProcessResult(service);
		dispatch_release(source);
	});
	
	dispatch_resume(source);
}

#endif
