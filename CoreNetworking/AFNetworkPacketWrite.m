//
//  AFPacketWrite.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkPacketWrite.h"

#import "AFNetworkFunctions.h"

@interface AFNetworkPacketWrite ()
@property (assign) NSUInteger totalBytesWritten;
@end

@implementation AFNetworkPacketWrite

@synthesize totalBytesWritten=_totalBytesWritten;
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

- (float)currentProgressWithBytesDone:(NSInteger *)bytesDone bytesTotal:(NSInteger *)bytesTotal {
	NSInteger done = [self totalBytesWritten], total = [self.buffer length];
	if (bytesDone != NULL) *bytesDone = done;
	if (bytesTotal != NULL) *bytesTotal = total;
	return ((float)done/(float)total);
}

- (NSInteger)performWrite:(NSOutputStream *)writeStream {
	NSInteger currentBytesWritten = 0;
	
	while ([writeStream hasSpaceAvailable]) {
		NSInteger bytesRemaining = ([self.buffer length] - [self totalBytesWritten]);
		uint8_t *writeBuffer = (uint8_t *)([self.buffer bytes] + [self totalBytesWritten]);
		
		NSInteger bytesWritten = [writeStream write:writeBuffer maxLength:bytesRemaining];
		if (bytesWritten < 0) {
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  [writeStream streamError], AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return -1;
		}
		
		[self setTotalBytesWritten:([self totalBytesWritten] + bytesWritten)];
		currentBytesWritten += bytesWritten;
		
		BOOL packetComplete = ([self totalBytesWritten] == [self.buffer length]);
		if (packetComplete) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
			break;
		}
	}
	
	return currentBytesWritten;
}

@end
