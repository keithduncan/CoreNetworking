//
//  AFPacketReadToWriteStream.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010 Realmac Software. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

@class AFPacketRead;

/*!
	@brief
	Acts as an adaptor between streams, allowing you to read a large file over the wire to disk.
	
	@detail
	Currently, all write stream operations are blocking, this restricts practical usage to file streams.
 */
@interface AFPacketReadToWriteStream : AFPacket <AFPacketReading> {
 @private
	BOOL _opened;
	__strong CFWriteStreamRef _writeStream;
	NSInteger _numberOfBytesToWrite;
	AFPacketRead *_currentRead;
	
	NSData *_writeBuffer;
}

/*!
	@brief
	Designated Initialiser.
 */
- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration writeStream:(CFWriteStreamRef)writeStream numberOfBytesToWrite:(NSInteger)numberOfBytesToWrite;

@end
