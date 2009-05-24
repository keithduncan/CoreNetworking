//
//  ServiceController.m
//  Bonjour
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

/*! ServiceController was taken from Apple's DNSServiceBrowser.m */
/*! Adapted from Adium implementation, improved and simplified by Keith Duncan */
/*! Modified to conform to a run loop source like API by Keith Duncan */

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
	[self init];
	
	_service = service;
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketContext));
	context.info = self;
	
	_socket = (CFSocketRef)NSMakeCollectable(CFSocketCreateWithNative(kCFAllocatorDefault, DNSServiceRefSockFD(_service), kCFSocketReadCallBack, AFServiceDiscoveryProcessResult, &context));
	CFSocketSetSocketFlags(_socket, (CFOptionFlags)0); // Note: don't close the underlying socket
	
	_source = (CFRunLoopSourceRef)NSMakeCollectable(CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, (CFIndex)0));
	
	[self scheduleInRunLoop:CFRunLoopGetCurrent() forMode:kCFRunLoopCommonModes];
	
	return self;
}

- (void)dealloc {
	CFRelease(_socket);
	CFRelease(_source);
	
	[super dealloc];
}

- (void)scheduleInRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode {
	CFRunLoopAddSource(loop, _source, mode);
}

- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode {
	CFRunLoopRemoveSource(loop, _source, mode);
}

- (void)invalidate {
	CFSocketInvalidate(_socket);
}

@end
