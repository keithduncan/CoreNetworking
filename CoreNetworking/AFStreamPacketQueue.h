//
//  AFStreamPacketQueue.h
//  Amber
//
//  Created by Keith Duncan on 25/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFPacketQueue.h"

@class AFPacket;
@protocol AFStreamPacketQueueDelegate;

@interface AFStreamPacketQueue : AFPacketQueue {
	id <AFStreamPacketQueueDelegate> _delegate;
	
	__strong id _stream;
	
	NSUInteger _flags;
	BOOL _dequeuing;
}

- (id)initWithStream:(id)stream delegate:(id <AFStreamPacketQueueDelegate>)delegate;

@property (readonly, retain) id stream;
@property (assign) NSUInteger flags;

- (void)tryDequeuePackets;

@end


@protocol AFStreamPacketQueueDelegate <NSObject>

/*!
	@brief
	The delegate is asked if the stream queue can start dequeuing.
 */
- (BOOL)streamQueueCanDequeuePackets:(AFStreamPacketQueue *)queue;

/*!
	@brief
	The delegate is called to actually perform the packet action, because it will vary from stream to stream.
 
	@result
	TRUE to dequeue the packet that was passed in and try another. The queue will keep trying packets until you return FALSE.
 */
- (BOOL)streamQueue:(AFStreamPacketQueue *)queue shouldTryDequeuePacket:(AFPacket *)packet;

@end
