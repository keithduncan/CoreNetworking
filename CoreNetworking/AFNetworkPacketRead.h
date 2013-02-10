//
//  AFPacketRead.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkPacket.h"

/*!
	\brief
	Standard read packet.
 */
@interface AFNetworkPacketRead : AFNetworkPacket <AFNetworkPacketReading> {
 @private
	id _terminator;
	
	NSUInteger _totalBytesRead;
	NSMutableData *_buffer;
}

/*!
	\brief
	Designated initialiser.
	
	\param terminator
	If you pass an `NSNumber` object, the packet reads a fixed number of bytes.
	If you pass an `NSData` object, the byte pattern is matched, all data upto and including the byte pattern is returned.
	If you pass an `NSNull` object, all available data is read.
 */
- (id)initWithTerminator:(id)terminator;

/*!
	\brief
	Initialised terminator
 */
@property (readonly, copy, nonatomic) id terminator;

@end
