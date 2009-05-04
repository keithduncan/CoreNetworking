//
//  ServiceController.h
//  Bonjour
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <dns_sd.h>

/*!
	@class
	@abstract    Allows for asynchronous DNSService API callbacks
	@discussion  This class doesn't take ownership of the DNSServiceRef it is instantiated with, it is still the client's responsibility to deallocate the DNSServiceRef once it is no longer needed
*/
@interface AFServiceDiscoveryRunLoopSource : NSObject {
	DNSServiceRef _service;
	
	__strong CFSocketRef _socket;	
	__strong CFRunLoopSourceRef _source;
}

/*!
	@method
 */
- (id)initWithService:(DNSServiceRef)service;

/*!
	@property
 */
@property (readonly) DNSServiceRef service;

/*!
	@method
 */
- (void)scheduleInRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode;

/*!
	@method
 */
- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode;

/*!
	@method
 */
- (void)invalidate;

@end
