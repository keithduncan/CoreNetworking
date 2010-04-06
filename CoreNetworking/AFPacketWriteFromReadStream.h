//
//  AFPacketWriteFromReadStream.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

@class AFNetworkReadStream;
@class AFPacketRead;
@class AFPacketWrite;

/*!
	@brief
	Acts as an adaptor between streams, allowing you to write a large file out over the wire.
	
	@detail
	Currently, all read stream operations are blocking, this restricts practical usage to file streams.
 */
@interface AFPacketWriteFromReadStream : AFPacket <AFPacketWriting> {
 @private
	NSInteger _numberOfBytesToRead;
	
	BOOL _opened;
	AFNetworkReadStream *_readStream;
	AFPacketRead *_currentRead;
	
	AFPacketWrite *_currentWrite;
}

/*!
	@brief
	Designated Initialiser.
	
	@param readStream
	Ownership is taken of the read stream and a new client set, the stream should be closed when passing it.
	
	@param numberOfBytesToRead
	Pass -1 to read until the stream is empty.
 */
- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration readStream:(NSInputStream *)readStream numberOfBytesToRead:(NSInteger)numberOfBytesToRead;

@end
