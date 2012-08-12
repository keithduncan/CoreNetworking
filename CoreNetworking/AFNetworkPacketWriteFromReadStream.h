//
//  AFPacketWriteFromReadStream.h
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
	Acts as an adaptor between streams, allowing you to write a large file out over the wire.
	
	\details
	Currently, all read stream operations are blocking, this restricts practical usage to file streams.
 */
@interface AFNetworkPacketWriteFromReadStream : AFNetworkPacket <AFNetworkPacketWriting> {
 @private
	NSInteger _totalBytesToRead;
	NSInteger _bytesRead;
	
	AFNETWORK_STRONG uint8_t *_readBuffer;
	size_t _bufferSize;
	
	size_t _bufferOffset;
	size_t _bufferLength;
	
	NSInputStream *_readStream;
	BOOL _readStreamOpened;
	BOOL _readStreamClosed;
	
#if NS_BLOCKS_AVAILABLE
	NSData * (^_readStreamFilter)(NSData *);
#else
	void *_readStreamFilter;
#endif /* NS_BLOCKS_AVAILABLE */
}

/*!
	\brief
	Designated Initialiser.
	
	\param readStream
	The stream should not be open, an exception is thrown if it is.
	
	\param totalBytesToWrite
	Pass -1 to read until the readStream is at end.
 */
- (id)initWithReadStream:(NSInputStream *)readStream totalBytesToRead:(NSInteger)totalBytesToRead;

#if NS_BLOCKS_AVAILABLE

/*!
	\brief
	Bytes read from the stream are transformed using this filter before being written to the output stream.
 */
@property (copy, nonatomic) NSData * (^readStreamFilter)(NSData *);

#endif /* NS_BLOCKS_AVAILABLE */

@end
