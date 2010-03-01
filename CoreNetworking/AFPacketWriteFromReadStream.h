//
//  AFPacketWriteFromReadStream.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010 Realmac Software. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

@class AFPacketWrite;

/*!
	@brief
	Acts as an adaptor between streams, allowing you to write a large file out over the wire.
	
	@detail
	Currently, all read stream operations are blocking, this restricts practical usage to file streams.
 */
@interface AFPacketWriteFromReadStream : AFPacket <AFPacketWriting> {
 @private
	BOOL _opened;
	__strong CFReadStreamRef _readStream;
	NSInteger _numberOfBytesToRead;
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
- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration readStream:(CFReadStreamRef)readStream numberOfBytesToRead:(NSInteger)numberOfBytesToRead;

@end
