//
//  AFPacketWrite.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFPacketWrite.h"

#import "AFNetworkFunctions.h"

@implementation AFPacketWrite

@synthesize buffer=_buffer;

- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration data:(NSData *)buffer {
	[self initWithTag:tag timeout:duration];
	
	_buffer = [buffer retain];
	
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

- (BOOL)performWrite:(CFWriteStreamRef)writeStream error:(NSError **)errorRef {
	BOOL packetComplete = NO;
	
	while (!packetComplete && CFWriteStreamCanAcceptBytes(writeStream)) {
		NSUInteger bytesRemaining = ([self.buffer length] - _bytesWritten);
		
		UInt8 *writeStart = (UInt8 *)([self.buffer bytes] + _bytesWritten);
		CFIndex actualBytesWritten = CFWriteStreamWrite(writeStream, writeStart, bytesRemaining);
		
		if (actualBytesWritten < 0) {
			*errorRef = AFErrorFromCFStreamError(CFWriteStreamGetError(writeStream));
			return NO;
		}
		
		_bytesWritten += actualBytesWritten;
		packetComplete = (_bytesWritten == [self.buffer length]);
	}
	
	return packetComplete;
}

@end
