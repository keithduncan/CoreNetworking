//
//  AFPacketRead.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

@interface AFPacketRead : AFPacket <AFPacketReading> {
 @private
	CFIndex _bytesRead;
	NSMutableData *_buffer;
	
	id _terminator;
}

- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration terminator:(id)terminator;

@end
