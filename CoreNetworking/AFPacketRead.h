//
//  AFPacketRead.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

/*!
	\brief
	This is a standard read packet.
	
	\param terminator
	If you pass an <tt>NSNumber</tt> object, the packet reads a fixed number of bytes.
	If you pass an <tt>NSData</tt> object, the byte pattern is matched, all data upto and including the byte pattern is returned.
	If you pass an <tt>NSNull</tt> object, all available data is read.
 */
@interface AFPacketRead : AFPacket <AFPacketReading> {
 @private
	id _terminator;
	
	NSUInteger _bytesRead;
	NSMutableData *_buffer;
}

/*!
	\brief
	Designated initialiser.
 */
- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration terminator:(id)terminator;

@end
