//
//  AFServiceDiscoveryRunLoopSource.h
//  Amber
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <dns_sd.h>

/*!
	@brief
	Allows for asynchronous DNSService API callbacks.
 
	@detail
	This class doesn't take ownership of the DNSServiceRef it is instantiated with, it is still the client's responsibility to deallocate the DNSServiceRef once it is no longer needed
*/
@interface AFServiceDiscoveryRunLoopSource : NSObject {
	DNSServiceRef _service;
	
	__strong CFSocketRef _socket;	
	__strong CFRunLoopSourceRef _source;
}

/*!
	@brief
	Because the DNS-SD doesn't provide a reference counting mechanism, you must ensure the service remains valid for the lifetime of this object.
	The source is scheduled on the current run loop.
 */
- (id)initWithService:(DNSServiceRef)service;

@property (readonly) DNSServiceRef service;

/*!
	@brief
	The source must be scheduled in at least one run loop to function.
 */
- (void)scheduleInRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode;

/*!
	@brief
	The source must be scheduled in at least one run loop to function.
 */
- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode;

- (void)invalidate;

@end
