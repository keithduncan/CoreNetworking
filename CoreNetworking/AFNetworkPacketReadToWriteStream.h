//
//  AFPacketReadToWriteStream.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkPacket.h"

@class AFNetworkWriteStream;
@class AFNetworkPacketRead;

/*!
	\brief
	Acts as an adaptor between streams, allowing you to read a large file over the wire to disk.
	
	\details
	Currently, all write stream operations are blocking, this restricts practical usage to file streams.
 */
@interface AFNetworkPacketReadToWriteStream : AFNetworkPacket <AFNetworkPacketReading> {
 @private
	NSInteger _numberOfBytesToRead;
	
	BOOL _opened;
	AFNetworkWriteStream *_writeStream;
	
	AFNetworkPacketRead *_currentRead;
}

/*!
	\brief
	Designated Initialiser.
 */
- (id)initWithWriteStream:(NSOutputStream *)writeStream numberOfBytesToRead:(NSInteger)numberOfBytesToRead;

@end
