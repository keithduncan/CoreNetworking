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

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration terminator:(id)terminator;

@end
