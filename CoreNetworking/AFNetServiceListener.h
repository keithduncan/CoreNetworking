//
//  ServiceController.h
//  Bonjour
//
//  Created by Keith Duncan on 09/11/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <dns_sd.h>

@protocol DNSRequestListenerDelegate;

/*!
    @class
    @abstract    Allows for Asynchronous DNSService API callbacks
    @discussion  This class doesn't take ownership of the DNSServiceRef it is instantiated with, it is still the client's responsibility to deallocate the DNSServiceRef once it is no longer needed
*/

@interface AFNetServiceListener : NSObject {
	id <DNSRequestListenerDelegate> delegate;
	
	DNSServiceRef service;
	CFSocketRef socket;
	
	CFRunLoopRef runLoop;
	CFRunLoopSourceRef runLoopSource;
}

@property (readonly) DNSServiceRef serviceRef;
- (id)initWithService:(DNSServiceRef)serviceRef runLoop:(CFRunLoopRef)loop;

@property (assign) id <DNSRequestListenerDelegate> delegate;

- (void)listen;

@end

@protocol DNSRequestListenerDelegate <NSObject>
- (void)listener:(AFNetServiceListener *)object didProcessWithCode:(DNSServiceErrorType)code;
@end
