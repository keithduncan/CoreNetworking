//
//  AFPacketQueue.h
//  Amber
//
//  Created by Keith Duncan on 02/04/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@brief
	The intended usage is that you add packets using <tt>-enqueuePacket:</tt>.
	You observe the <tt>currentWritePacket</tt> property to learn when there's a new packet to process.
	Then call <tt>-dequeuePacket</tt> once you've finished processing the <tt>currentPacket</tt>.
 */
@interface AFPacketQueue : NSObject {	
	NSMutableArray *_packets;
	id _currentPacket;
}

- (NSUInteger)count;

- (void)enqueuePacket:(id)packet;

/*!
	@brief
	This property will change when a packet is dequeued, you can observe it to determine when there is work to be done.
 */
@property (readonly, retain) id currentPacket;

/*!
	@brief
	Call this method to shift a packet out of the queue into the currentPacket position.
	If the queue is empty, or there is already a |currentPacket| this method returns false. 
	
	@result
	(self.currentPacket != nil)
 */
- (BOOL)tryDequeue;

/*!
	@brief
	This method should be called once you have processed the |currentPacket| to allow another to be shifted into the |currentPacket| position.
 */
- (void)dequeued;

/*!
	@brief
	The method first removes all queued packets, then calls <tt>-dequeuePacket</tt>. This ensures that when terminating, you can flush the queue, without starting a new packet.
 */
- (void)emptyQueue;

@end
