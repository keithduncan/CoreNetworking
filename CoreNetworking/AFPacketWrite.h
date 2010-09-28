//
//  AFPacketWrite.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

/*!
	@brief
	This is a standard write packet.
 */
@interface AFPacketWrite : AFPacket <AFPacketWriting> {
 @private
	NSData *_buffer;
	NSUInteger _bytesWritten;
	
	NSInteger _chunkSize;
}

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration data:(NSData *)buffer;

/*!
	@brief
	This property allows you to simulate a smaller socket buffer when using the CFStreamRef subclasses.
	
	@details
	The default value of this property is -1 which limits each write to the maximum size of the kernel buffer.
 */
@property (assign) NSInteger chunkSize;

@end
