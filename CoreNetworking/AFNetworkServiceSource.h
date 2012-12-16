//
//  AFServiceDiscoveryRunLoopSource.h
//  Amber
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <dns_sd.h>

#import "CoreNetworking/AFNetwork-Macros.h"

/*!
	\brief
	Allows for asynchronous DNSService API callbacks.
 
	\details
	This class doesn't take ownership of the DNSServiceRef it is instantiated with, it is still the client's responsibility to deallocate the DNSServiceRef once it is no longer needed.
*/
@interface AFNetworkServiceSource : NSObject {
 @private
	DNSServiceRef _service;
	
	AFNETWORK_STRONG CFFileDescriptorRef _fileDescriptor;
	
	struct {
		AFNETWORK_STRONG CFTypeRef _runLoopSource;
		void *_dispatchSource;
	} _sources;
}

/*!
	\brief
	Because the DNS-SD doesn't provide a reference counting mechanism, you must ensure the service remains valid for the lifetime of this object.
 */
- (id)initWithService:(DNSServiceRef)service;

@property (readonly, nonatomic) DNSServiceRef service;

/*!
	\brief
	The source must be scheduled in at least one run loop to function.
 */
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

/*!
	\brief
	The source must be scheduled in at least one run loop to function.
 */
- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

/*!
	\brief
	Creates a dispatch source internally.
	
	\param queue
	A layer can only be scheduled in a single queue at a time, to unschedule it pass NULL.
 */
- (void)scheduleInQueue:(dispatch_queue_t)queue;

/*!
	\brief
	Should be called to unschedule the source from all event loops.
 */
- (void)invalidate;

/*!
	\brief
	Once invalidated, a source won't fire any more.
 */
- (BOOL)isValid;

@end

/*!
	\brief
	Create and schedule a dispatch source for the mDNSResponder socket held by the service argument.
	
	\details
	This source acts like the Cocoa `-performSelector:...` methods, it creates and destroys a behind the scenes source for you.
	
	\param service
	Must not be NULL
	
	\param queue
	Must not be NULL
	
	\return
	Does not return an owning reference, you must retain it if you keep a reference for later cancellation.
 */
AFNETWORK_EXTERN dispatch_source_t AFNetworkServiceCreateQueueSource(DNSServiceRef service, dispatch_queue_t queue);
