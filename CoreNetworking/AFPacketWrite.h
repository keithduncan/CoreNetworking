//
//  AFPacketWrite.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

/*!
	\brief
	This is a standard write packet.
 */
@interface AFPacketWrite : AFPacket <AFPacketWriting> {
 @private
	NSData *_buffer;
	NSUInteger _bytesWritten;
}

/*!
	\brief
	Designated Initialiser.
 */
- (id)initWithData:(NSData *)buffer;

@end
