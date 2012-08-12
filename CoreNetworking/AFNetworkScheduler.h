//
//  AFNetworkScheduler.h
//  CoreNetworking
//
//  Created by Keith Duncan on 03/10/2011.
//  Copyright 2011 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AFNetworkLayer;

/*!
	\brief
	Define scheduling characteristics for network layers.
 */
@interface AFNetworkScheduler : NSObject {
 @private
	NSUInteger _type;
	
	union {
		__strong CFMutableDictionaryRef _runLoopToModeMap;
		void *_dispatchQueue;
	} _scheduler;
}

- (id)initWithRunLoop:(NSRunLoop *)runLoop modes:(NSSet *)modes;

#if defined(DISPATCH_API_VERSION)

- (id)initWithQueue:(dispatch_queue_t)queue;

#endif

- (void)scheduleLayer:(AFNetworkLayer *)networkLayer;
- (void)unscheduleLayer:(AFNetworkLayer *)networkLayer;

@end
