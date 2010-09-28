//
//  AFPacketReadToWriteStream.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

@class AFNetworkWriteStream;
@class AFPacketRead;

/*!
	@brief
	Acts as an adaptor between streams, allowing you to read a large file over the wire to disk.
	
	@details
	Currently, all write stream operations are blocking, this restricts practical usage to file streams.
 */
@interface AFPacketReadToWriteStream : AFPacket <AFPacketReading> {
 @private
	NSInteger _numberOfBytesToRead;
	
	BOOL _opened;
	AFNetworkWriteStream *_writeStream;
	
	AFPacketRead *_currentRead;
}

/*!
	@brief
	Designated Initialiser.
 */
- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration writeStream:(NSOutputStream *)writeStream numberOfBytesToRead:(NSInteger)numberOfBytesToRead;

@end
