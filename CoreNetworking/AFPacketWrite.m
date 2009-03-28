//
//  AFPacketWrite.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFPacketWrite.h"

#define WRITE_CHUNKSIZE    (1024 * 4)   // Limit on size of each write pass

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

- (void)progress:(float *)fraction done:(NSUInteger *)bytesDone total:(NSUInteger *)bytesTotal {
	CFIndex done = _bytesWritten;
	CFIndex total = [self.buffer length];
	
	if (fraction != NULL) *fraction = (float)done/(float)total;
	if (bytesDone != NULL) *bytesDone = done;
	if (bytesTotal != NULL) *bytesTotal = total;
}

- (BOOL)performWrite:(CFWriteStreamRef)writeStream error:(NSError **)errorRef {
	BOOL packetComplete = NO, streamError = NO;
	while (!packetComplete && !streamError && CFWriteStreamCanAcceptBytes(writeStream)) {
		// Figure out what to write.
		NSUInteger bytesRemaining = ([self.buffer length] - _bytesWritten);
		NSUInteger bytesToWrite = (bytesRemaining < WRITE_CHUNKSIZE) ? bytesRemaining : WRITE_CHUNKSIZE;
		
		UInt8 *writeStart = (UInt8 *)([self.buffer bytes] + _bytesWritten);
		CFIndex actualBytesWritten = CFWriteStreamWrite(writeStream, writeStart, bytesToWrite);
		
		if (actualBytesWritten < 0) {
			actualBytesWritten = 0;
			streamError = YES;
		}
		
		_bytesWritten += actualBytesWritten;
		packetComplete = ( _bytesWritten == [self.buffer length]);
	}
	
	if (streamError) {
		*errorRef = [self errorFromCFStreamError:CFWriteStreamGetError(writeStream)];
	}
	
	return packetComplete;
}

@end

#undef WRITE_CHUNKSIZE
