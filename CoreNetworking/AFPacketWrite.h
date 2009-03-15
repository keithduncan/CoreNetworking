//
//  AFPacketWrite.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

@interface AFPacketWrite : AFPacket {
	NSData *_buffer;
	NSUInteger _bytesWritten;
}

- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration data:(NSData *)buffer;

/*!
	@method	
	@result	true if the packet is complete
 */
- (BOOL)performWrite:(CFWriteStreamRef)writeStream error:(NSError **)errorRef;

@end
