//
//  AFPacketWrite.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFPacketWrite.h"

#import "AFNetworkFunctions.h"

@implementation AFPacketWrite

@synthesize buffer=_buffer;
@synthesize chunkSize=_chunkSize;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_chunkSize = -1;
	
	return self;
}

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration data:(NSData *)buffer {
	self = [self initWithContext:context timeout:duration];
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
	BOOL packetComplete = NO;
	
	while (!packetComplete && [writeStream hasSpaceAvailable]) {
		NSUInteger bytesRemaining = ([self.buffer length] - _bytesWritten);
		if (self.chunkSize > 0 && bytesRemaining > self.chunkSize) bytesRemaining = self.chunkSize;
		
		uint8_t *writeBuffer = (UInt8 *)([self.buffer bytes] + _bytesWritten);
		NSUInteger actualBytesWritten = [writeStream write:writeBuffer maxLength:bytesRemaining];
		
		if (actualBytesWritten < 0) {
			NSError *error = [writeStream streamError];
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  error, AFPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return;
		}
		
		_bytesWritten += actualBytesWritten;
		packetComplete = (_bytesWritten == [self.buffer length]);
		if (self.chunkSize > 0) break;
	}
	
	if (packetComplete) [[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
}

@end
