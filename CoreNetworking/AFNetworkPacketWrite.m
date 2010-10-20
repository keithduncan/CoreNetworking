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
	CFIndex done = _bytesWritten, total = [self.buffer length];
	
	if (bytesDone != NULL) *bytesDone = done;
	if (bytesTotal != NULL) *bytesTotal = total;
	return ((float)done/(float)total);
}

- (NSInteger)performWrite:(NSOutputStream *)writeStream {
	NSInteger currentBytesWritten = 0;
	
	while ([writeStream hasSpaceAvailable]) {
		uint8_t *writeBuffer = (uint8_t *)([self.buffer bytes] + _bytesWritten);
		NSInteger bytesRemaining = ([self.buffer length] - _bytesWritten);
		
		NSInteger bytesWritten = [writeStream write:writeBuffer maxLength:bytesRemaining];
		
		if (bytesWritten < 0) {
			NSError *error = [writeStream streamError];
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  error, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return -1;
		}
		
		_bytesWritten += bytesWritten;
		
		BOOL packetComplete = NO;
		packetComplete = (_bytesWritten == [self.buffer length]);
		
		if (packetComplete) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
			break;
		}
	}
	
	return currentBytesWritten;
}

@end
