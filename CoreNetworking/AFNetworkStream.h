//
//  AFNetworkStream.h
//  Amber
//
//  Created by Keith Duncan on 02/03/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkPacketQueue;
@class AFNetworkPacket;

@class AFNetworkStream;

@protocol AFNetworkStreamDelegate <NSObject>

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

/*!
	\brief
	You must implement this method to handle any errors; errors must be handled.
 */
- (void)networkStream:(AFNetworkStream *)networkStream didReceiveError:(NSError *)error;

 @optional

/*!
	\brief
	Implement to know when a packet has been removed from the stream's queue.
 */
- (void)networkStream:(AFNetworkStream *)networkStream didDequeuePacket:(AFNetworkPacket *)packet;

/*!
	\brief
	Implement this method to be informed of packet progress.
 */
- (void)networkStream:(AFNetworkStream *)networkStream didTransfer:(AFNetworkPacket *)packet bytesTransferred:(NSInteger)bytesTransferred totalBytesTransferred:(NSInteger)totalBytesTransferred totalBytesExpectedToTransfer:(NSInteger)totalBytesExpectedToTransfer;

@end

#pragma mark -

/*!
	\brief
	
 */
@interface AFNetworkStream : NSObject {
 @protected
	id <AFNetworkStreamDelegate> _delegate;
	
	NSStream *_stream;
	SEL _performSelector;
	
	NSUInteger _streamFlags;
	
	struct {
		AFNETWORK_STRONG CFTypeRef _runLoopSource;
		AFNETWORK_STRONG void *_dispatchSource;
	} _sources;
	
	NSUInteger _queueSuspendCount;
	AFNetworkPacketQueue *_packetQueue;
	BOOL _dequeuing;
	
	NSTimer *_timeoutTimer;
}

/*
	Creation
 */

/*!
	\brief
	The stream MUST be unopened, this is asserted.
 */
- (id)initWithStream:(NSStream *)stream;

@property (assign, nonatomic) id <AFNetworkStreamDelegate> delegate;

/*
	Scheduling
	
	Used to schedule the underlying stream and timeout timer.
 */

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue;

#endif /* defined(DISPATCH_API_VERSION) */

/*
	State
 */

- (void)open;
- (BOOL)isOpen;

- (void)close;
- (BOOL)isClosed;

- (id)streamPropertyForKey:(NSString *)key;
- (BOOL)setStreamProperty:(id)property forKey:(NSString *)key;

/*
	Queue
 */

- (void)enqueuePacket:(AFNetworkPacket *)packet;
- (NSUInteger)countOfEnqueuedPackets;

- (void)suspendPacketQueue;
- (void)resumePacketQueue;

@end
