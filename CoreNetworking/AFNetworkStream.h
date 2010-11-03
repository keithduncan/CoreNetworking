//
//  AFNetworkStream.h
//  Amber
//
//  Created by Keith Duncan on 02/03/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AFNetworkPacketQueue;
@class AFNetworkPacket;

@protocol AFNetworkStreamDelegate;

/*!
	\brief
	
 */
@interface AFNetworkStream : NSObject {
 @protected
	id <AFNetworkStreamDelegate> _delegate;
	
	NSStream *_stream;
	SEL _performSelector;
	
	NSUInteger _flags;
	
	__strong CFMutableDictionaryRef _runLoopSources;
	void *_dispatchSource;
	
	AFNetworkPacketQueue *_queue;
	BOOL _dequeuing;
}

/*
	Creation
 */

/*!
	\brief
	The stream MUST be unopened, this is asserted.
 */
- (id)initWithStream:(NSStream *)stream;

@property (assign) id <AFNetworkStreamDelegate> delegate;

/*
	Scheduling
 */

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

#if defined(DISPATCH_API_VERSION)
- (void)scheduleInQueue:(dispatch_queue_t)queue;
#endif

/*
	State
 */

- (void)open;
- (void)close;

- (id)streamPropertyForKey:(NSString *)key;
- (BOOL)setStreamProperty:(id)property forKey:(NSString *)key;

/*
	Queue
 */

- (void)enqueuePacket:(AFNetworkPacket *)packet;
- (NSUInteger)countOfEnqueuedPackets;

@end

#pragma mark -

@protocol AFNetworkStreamDelegate <NSObject>

 @optional

/*!
	\brief
	YES is assumed if unimplemented.
 */
- (BOOL)networkStreamCanDequeuePackets:(AFNetworkStream *)networkStream;

- (void)networkStream:(AFNetworkStream *)networkStream didTransfer:(AFNetworkPacket *)packet bytesTransferred:(NSInteger)bytesTransferred totalBytesTransferred:(NSInteger)totalBytesWritten totalBytesExpectedToTransfer:(NSInteger)totalBytesExpectedToTransfer;

 @required

/*!
	\brief
	Only the following events are forwarded before being processed internally
	
	- NSStreamEventOpenCompleted
	- NSStreamEventHasBytesAvailable
	- NSStreamEventHasSpaceAvailable
	- NSStreamEventEndEncountered
	
	all other events are captured and processed.
 */
- (void)networkStream:(AFNetworkStream *)networkStream didReceiveEvent:(NSStreamEvent)event;

- (void)networkStream:(AFNetworkStream *)networkStream didReceiveError:(NSError *)error;

- (void)networkStream:(AFNetworkStream *)networkStream didDequeuePacket:(AFNetworkPacket *)packet;

@end
