//
//  AFPacketReadToWriteStream.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkPacket.h"

/*!
	\brief
	Acts as an adaptor between streams, allowing you to read a large file over the wire to disk.
	
	\details
	Currently, all write stream operations are blocking, this restricts practical usage to file streams.
 */
@interface AFNetworkPacketReadToWriteStream : AFNetworkPacket <AFNetworkPacketReading> {
 @private
	NSInteger _totalBytesToRead;
	NSInteger _bytesRead;
	
	__strong uint8_t *_readBuffer;
	size_t _bufferSize;
	
	NSOutputStream *_writeStream;
	BOOL _writeStreamOpen;
}

/*!
	\brief
	Designated Initialiser.
 
	\param writeStream
	The stream should not be open, an exception is thrown if it is.
	
	\param totalBytesToRead
	Pass -1 to write until the writeStream is at end.
 */
- (id)initWithWriteStream:(NSOutputStream *)writeStream totalBytesToRead:(NSInteger)totalBytesToRead;

@end
