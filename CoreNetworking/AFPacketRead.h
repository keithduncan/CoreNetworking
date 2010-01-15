//
//  AFPacketRead.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

/*!
	@brief
	This is a standard read packet. It may be instantiated with either a NSNumber or an NSData terminator; indicating the number of bytes to read or the pattern to read up to, respectively.
 */
@interface AFPacketRead : AFPacket <AFPacketReading> {
 @private
	CFIndex _bytesRead;
	NSMutableData *_buffer;
	
	id _terminator;
}

/*!
	@brief
	Designated initialiser.
 */
- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration terminator:(id)terminator;

@end
