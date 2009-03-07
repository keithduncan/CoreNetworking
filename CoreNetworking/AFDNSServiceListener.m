//
//  ServiceController.m
//  Bonjour
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

/* ServiceController was taken from Apple's DNSServiceBrowser.m */
/* Adapted from Adium implementation, improved and simplified by Keith Duncan */

#import "AFDNSServiceListener.h"

@interface AFDNSServiceListener (Private)
- (void)_setupCallback;
- (void)_teardownCallback;
@end

@implementation AFDNSServiceListener

@synthesize delegate;
@synthesize serviceRef=service;

- (id)initWithService:(DNSServiceRef)serviceRef runLoop:(CFRunLoopRef)runLoop {
	[self init];
	
	service = serviceRef;
	
	runLoop = runLoop;
	CFRetain(runLoop);
	
	return self;
}

- (void)dealloc {
	[self _teardownCallback];
	
	CFRelease(runLoop);
	
	[super dealloc];
}

- (void)listen {
#if 1 /* Asynchronously */
	[self _setupCallback];
#else /* Synchronously */
	DNSServiceErrorType error = kDNSServiceErr_NoError;
	error = DNSServiceProcessResult([self serviceRef]);
#endif
}

@end

@implementation AFDNSServiceListener (Private)

static void	ProcessSockData(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
	AFDNSServiceListener *self = info;
	
	DNSServiceErrorType error = kDNSServiceErr_NoError;
	error = DNSServiceProcessResult(self->service);
	
	[self->delegate listener:self didProcessWithCode:error];
}

- (void)_setupCallback {
	CFSocketContext context = {1, self, NULL, NULL, NULL};
	socket = CFSocketCreateWithNative(kCFAllocatorDefault, DNSServiceRefSockFD(service), kCFSocketReadCallBack, ProcessSockData, &context);
	CFSocketSetSocketFlags(socket, (CFOptionFlags)0); // Note: don't close the underlying socket
	
	runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, (CFIndex)1);
	CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);
}

- (void)_teardownCallback {	
	if (socket != NULL) {
		CFSocketInvalidate(socket);
		CFRelease(socket);
	}
	
	if (runLoopSource != NULL) {
		CFRunLoopRemoveSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);
		CFRelease(runLoopSource);
	}
}

@end
