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

@class AFNetworkSchedule;

/*!
	\brief
	Allows for asynchronous DNSService API callbacks.
 
	\details
	This class doesn't take ownership of the DNSServiceRef it is instantiated
	with, it is still the client's responsibility to deallocate the
	DNSServiceRef once it is no longer needed.
*/
@interface AFNetworkServiceSource : NSObject {
 @private
	DNSServiceRef _service;
	
	AFNetworkSchedule *_schedule;
	struct {
		struct {
			AFNETWORK_STRONG CFFileDescriptorRef _fileDescriptor;
			AFNETWORK_STRONG CFRunLoopSourceRef _source;
		} _runLoop;
		void *_dispatchSource;
	} _sources;
}

/*!
	\brief
	Because the DNS-SD doesn't provide a reference counting mechanism, you must
	ensure the service remains valid for the lifetime of this object.
 */
- (id)initWithService:(DNSServiceRef)service;

@property (readonly, nonatomic) DNSServiceRef service;

/*!
	\brief
	The source must be scheduled in at least one environment to work.
 */
- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

/*!
	\brief
	The source must be scheduled in at least one environment to work.
 */
- (void)scheduleInQueue:(dispatch_queue_t)queue;

/*!
	\brief
	Must be sent after scheduling
 */
- (void)resume;

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
