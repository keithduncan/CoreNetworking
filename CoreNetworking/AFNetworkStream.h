//
//  AFNetworkStream.h
//  Amber
//
//  Created by Keith Duncan on 02/03/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AFNetworkPacketQueue;

@protocol AFNetworkStreamDelegate;
@protocol AFNetworkWriteStreamDelegate;
@protocol AFNetworkReadStreamDelegate;

@class AFNetworkPacket;
@protocol AFNetworkPacketReading;
@protocol AFNetworkPacketWriting;

#pragma mark -

@interface AFNetworkStream : NSObject {
 @protected
	id <AFNetworkStreamDelegate> _delegate;
	
	NSStream *_stream;
	
	SEL _callbackSelectors[2];
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

@end

@interface AFNetworkWriteStream : AFNetworkStream

@property (assign) id <AFNetworkWriteStreamDelegate> delegate;

- (void)enqueueWrite:(AFNetworkPacket <AFNetworkPacketWriting> *)packet;

@property (readonly) NSUInteger countOfEnqueuedWrites;

@end

@interface AFNetworkReadStream : AFNetworkStream

@property (assign) id <AFNetworkReadStreamDelegate> delegate;

- (void)enqueueRead:(AFNetworkPacket <AFNetworkPacketReading> *)packet;

@property (readonly) NSUInteger countOfEnqueuedReads;

@end

#pragma mark -

@protocol AFNetworkStreamDelegate <NSObject>

 @optional

- (BOOL)networkStreamCanDequeuePacket:(AFNetworkStream *)networkStream;

- (void)networkStreamDidDequeuePacket:(AFNetworkStream *)networkStream;

 @required

- (void)networkStream:(AFNetworkStream *)stream didReceiveEvent:(NSStreamEvent)event;

- (void)networkStream:(AFNetworkStream *)stream didReceiveError:(NSError *)error;

@end

#pragma mark -

@protocol AFNetworkWriteStreamDelegate <AFNetworkStreamDelegate>

 @optional

- (void)networkStream:(AFNetworkWriteStream *)stream didWrite:(id <AFNetworkPacketWriting>)packet partialDataOfLength:(NSUInteger)partialLength totalLength:(NSUInteger)totalLength;

 @required

- (void)networkStream:(AFNetworkWriteStream *)stream didWrite:(id <AFNetworkPacketWriting>)packet;

@end

#pragma mark -

@protocol AFNetworkReadStreamDelegate <AFNetworkStreamDelegate>

 @optional

- (void)networkStream:(AFNetworkReadStream *)readStream didRead:(id <AFNetworkPacketReading>)packet partialDataOfLength:(NSUInteger)partialLength totalLength:(NSUInteger)totalLength;

 @required

- (void)networkStream:(AFNetworkReadStream *)readStream didRead:(id <AFNetworkPacketReading>)packet;

@end
