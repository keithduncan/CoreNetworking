//
//  AFPacketWriteFromReadStream.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

@class AFNetworkReadStream;
@class AFNetworkWriteStream;

@class AFPacketRead;
@class AFPacketWrite;

/*!
	@brief
	Acts as an adaptor between streams, allowing you to write a large file out over the wire.
	
	@details
	Currently, all read stream operations are blocking, this restricts practical usage to file streams.
 */
@interface AFPacketWriteFromReadStream : AFPacket <AFPacketWriting> {
 @private
	NSInteger _numberOfBytesToWrite;
	
	NSInputStream *_readStream;
	BOOL _readStreamOpened, _readStreamComplete;
	
	NSUInteger _currentBufferOffset, _currentBufferLength;
	__strong uint8_t *_readBuffer;
}

/*!
	@brief
	Designated Initialiser.
	
	@param readStream
	Ownership is taken of the read stream and a new client set, the stream should be closed when passing it.
	
	@param numberOfBytesToRead
	Pass -1 to read until the stream is empty.
 */
- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration readStream:(NSInputStream *)readStream numberOfBytesToWrite:(NSInteger)numberOfBytesToWrite;

@end
