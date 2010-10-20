//
//  AFPacketWriteFromReadStream.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkPacket.h"

/*!
	\brief
	Acts as an adaptor between streams, allowing you to write a large file out over the wire.
	
	\details
	Currently, all read stream operations are blocking, this restricts practical usage to file streams.
 */
@interface AFNetworkPacketWriteFromReadStream : AFNetworkPacket <AFNetworkPacketWriting> {
 @private
	NSInteger _totalBytesToWrite;
	NSInteger _bytesWritten;
	
	__strong uint8_t *_readBuffer;
	size_t _bufferSize;
	
	size_t _bufferLength;
	size_t _bufferOffset;
	
	NSInputStream *_readStream;
	BOOL _readStreamOpen;
}

/*!
	\brief
	Designated Initialiser.
	
	\param readStream
	The stream should not be open, an exception is thrown if it is.
	
	\param totalBytesToWrite
	Pass -1 to read until the readStream is at end.
 */
- (id)initWithReadStream:(NSInputStream *)readStream totalBytesToWrite:(NSInteger)totalBytesToWrite;

@end
