//
//  AFServiceDiscoveryRunLoopSource.h
//  Amber
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <dns_sd.h>

/*!
	\brief
	Allows for asynchronous DNSService API callbacks.
 
	\details
	This class doesn't take ownership of the DNSServiceRef it is instantiated with, it is still the client's responsibility to deallocate the DNSServiceRef once it is no longer needed.
*/
@interface AFServiceDiscoveryRunLoopSource : NSObject {
 @private
	DNSServiceRef _service;
	
	__strong CFFileDescriptorRef _fileDescriptor;
	__strong CFRunLoopSourceRef _source;
}

/*!
	\brief
	Because the DNS-SD doesn't provide a reference counting mechanism, you must ensure the service remains valid for the lifetime of this object.
	The source is scheduled on the current run loop.
 */
- (id)initWithDNSService:(DNSServiceRef)service;

/*!
	\brief
	
 */
@property (readonly) DNSServiceRef service;

/*!
	\brief
	The source must be scheduled in at least one run loop to function.
 */
- (void)scheduleInRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode;

/*!
	\brief
	The source must be scheduled in at least one run loop to function.
 */
- (void)unscheduleFromRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode;

/*!
	\brief
	
 */
- (void)invalidate;

@end

#if defined(DISPATCH_API_VERSION)

/*!
	\brief
	Create and schedule a dispatch source for the mDNSResponder socket held by the service argument.
	
	\details
	This source acts like the Cocoa <tt>-performSelector:…</tt> methods, it creates and destroys a behind the scenes source for you.
 */
extern void AFServiceDiscoveryScheduleQueueSource(DNSServiceRef service, dispatch_queue_t queue);

#endif
