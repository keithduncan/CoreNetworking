//
//  ServiceController.h
//  Bonjour
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/CoreNetworking.h"

#import <dns_sd.h>

/*!
	@class
	@abstract    Allows for Asynchronous DNSService API callbacks
	@discussion  This class doesn't take ownership of the DNSServiceRef it is instantiated with, it is still the client's responsibility to deallocate the DNSServiceRef once it is no longer needed
*/
@interface AFServiceDiscoveryRunLoopSource : NSObject {
	DNSServiceRef _service;
	
	CFSocketRef _socket;	
	CFRunLoopSourceRef _source;
}

@property (readonly) DNSServiceRef service;
- (id)initWithService:(DNSServiceRef)service;

- (void)scheduleWithRunLoop:(CFRunLoopRef)loop;
- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop;

@end
