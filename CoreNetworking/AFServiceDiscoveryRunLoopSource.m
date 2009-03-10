//
//  ServiceController.m
//  Bonjour
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

/* ServiceController was taken from Apple's DNSServiceBrowser.m */
/* Adapted from Adium implementation, improved and simplified by Keith Duncan */
/* Modified to conform to a run loop source like API by Keith Duncan */

#import "AFServiceDiscoveryRunLoopSource.h"

@implementation AFServiceDiscoveryRunLoopSource

@synthesize service=_service;

static void	AFServiceDiscoveryProcessResult(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
	if (type != kCFSocketReadCallBack) return;
	AFServiceDiscoveryRunLoopSource *self = info;
	
	DNSServiceErrorType error = kDNSServiceErr_NoError;
	error = DNSServiceProcessResult(self->_service);
}

- (id)initWithService:(DNSServiceRef)service {
	[self init];
	
	_service = service;
	
	CFSocketContext context;
	memset(&context, 0, sizeof(CFSocketRef));
	
	context.info = self;
	
	_socket = CFSocketCreateWithNative(kCFAllocatorDefault, DNSServiceRefSockFD(_service), kCFSocketReadCallBack, AFServiceDiscoveryProcessResult, &context);
	CFSocketSetSocketFlags(_socket, (CFOptionFlags)0); // Note: don't close the underlying socket
	
	_source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, (CFIndex)0);
	
	return self;
}

- (void)dealloc {
	CFRelease(_socket);
	CFRelease(_source);
	
	[super dealloc];
}

- (void)scheduleWithRunLoop:(CFRunLoopRef)loop {
	CFRunLoopAddSource(loop, _source, kCFRunLoopDefaultMode);
}

- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop {
	CFRunLoopRemoveSource(loop, _source, kCFRunLoopDefaultMode);
}

- (void)invalidate {
	CFSocketInvalidate(_socket);
}

@end
