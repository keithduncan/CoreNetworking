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
	NSMutableArray *_queue;
	id _currentPacket;
}

- (NSUInteger)count;

- (void)enqueuePacket:(id)packet;

@property (readonly, retain) id currentPacket;

- (void)dequeuePacket;

/*!
	@brief
	The method first removes all queued packets, then sets the <tt>currentPacket</tt> to nil allowing you to clean up.
	This ensures that when terminating, you can flush the queue, without starting a new packet.
 */
- (void)emptyQueue;

@end
