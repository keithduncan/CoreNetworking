//
//  AFPacketReadToWriteStream.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkPacket.h"

#import "CoreNetworking/AFNetwork-Macros.h"

/*!
	\brief
	Acts as an adaptor between streams, allowing you to read a large file over
	the wire to disk.
	
	\details
	Currently, all write stream operations are blocking, this restricts
	practical usage to file streams.
 */
@interface AFNetworkPacketReadToWriteStream : AFNetworkPacket <AFNetworkPacketReading> {
 @private
	NSInteger _totalBytesToRead;
	NSInteger _bytesRead;
	
	AFNETWORK_STRONG uint8_t *_readBuffer;
	size_t _bufferSize;
	
	NSOutputStream *_writeStream;
	BOOL _writeStreamOpen;
}

/*!
	\brief
	Designated initialiser.
 
	\param writeStream
	The stream should not be open, an exception is thrown if it is.
	
	\param totalBytesToRead
	Pass -1 to read until the read stream is at end.
	
	\details
	writeStream is opened when this packet starts and is closed when this packet
	finishes.
 */
- (id)initWithTotalBytesToRead:(NSInteger)totalBytesToRead writeStream:(NSOutputStream *)writeStream;

@end
