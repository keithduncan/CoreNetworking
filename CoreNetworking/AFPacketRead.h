//
//  AFPacketRead.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

@interface AFPacketRead : AFPacket {
	CFIndex _bytesRead;	
	NSMutableData *_buffer;
	
	NSData *_terminator;
	CFIndex _maximumLength;
	
	BOOL _readAllAvailable;
}

- (id)initWithTag:(NSInteger)tag timeout:(NSTimeInterval)duration readAllAvailable:(BOOL)readAllAvailable terminator:(id)terminator;

/*!
	@method	
	@result	Returns true if the packet is complete
 */
- (BOOL)read:(CFReadStreamRef)stream error:(NSError **)errorRef;

@end
