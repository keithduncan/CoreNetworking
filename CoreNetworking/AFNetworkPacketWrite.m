//
//  AFPacketWrite.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkPacketWrite.h"

#import "AFNetworkFunctions.h"

@implementation AFNetworkPacketWrite

@synthesize buffer=_buffer;

- (id)initWithData:(NSData *)buffer {
	NSParameterAssert([buffer length] > 0);
	
	self = [self init];
	if (self == nil) return self;
	
	_buffer = [buffer copy];
	
	return self;
}

- (void)dealloc {
	[_buffer release];
	
	[super dealloc];
}

- (float)currentProgressWithBytesDone:(NSUInteger *)bytesDone bytesTotal:(NSUInteger *)bytesTotal {
	CFIndex done = _bytesWritten;
	CFIndex total = [self.buffer length];
	
	if (bytesDone != NULL) *bytesDone = done;
	if (bytesTotal != NULL) *bytesTotal = total;
	
	return ((float)done/(float)total);
}

- (void)performWrite:(NSOutputStream *)writeStream {
	if ([[self buffer] length] == 0) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
		return;
	}
	
	while ([writeStream hasSpaceAvailable]) {
		NSUInteger bytesRemaining = ([self.buffer length] - _bytesWritten);
		
		uint8_t *writeBuffer = (uint8_t *)([self.buffer bytes] + _bytesWritten);
		NSUInteger actualBytesWritten = [writeStream write:writeBuffer maxLength:bytesRemaining];
		
		if (actualBytesWritten < 0) {
			NSError *error = [writeStream streamError];
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  error, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return;
		}
		
		_bytesWritten += actualBytesWritten;
		
		BOOL packetComplete = NO;
		packetComplete = (_bytesWritten == [self.buffer length]);
		
		if (packetComplete) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
			return;
		}
	}
}

@end
