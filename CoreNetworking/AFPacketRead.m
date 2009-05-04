//
//  AFPacketRead.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFPacketRead.h"

#import "AFNetworkConstants.h"
#import "AFNetworkFunctions.h"

@implementation AFPacketRead

@synthesize buffer=_buffer;

- (id)init {
	[super init];
	
	_buffer = [[NSMutableData alloc] init];
	
	return self;
}

- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration terminator:(id)terminator {
	self = [self initWithTag:tag timeout:duration];
	if (self == nil) return nil;
	
	_terminator = [terminator copy];
	
	if ([_terminator isKindOfClass:[NSNumber class]]) {
		[_buffer setLength:[_terminator unsignedIntegerValue]];
	}
	
	return self;
}

- (void)dealloc {
	[_buffer release];
	[_terminator release];
	
	[super dealloc];
}

- (float)currentProgressWithBytesDone:(NSUInteger *)bytesDone bytesTotal:(NSUInteger *)bytesTotal {	
	BOOL hasTotal = ([_terminator isKindOfClass:[NSNumber class]]);
	
	NSUInteger done = _bytesRead;
	NSUInteger total = [self.buffer length];
	
	if (bytesDone != NULL) *bytesDone = done;
	if (bytesTotal != NULL) *bytesTotal = (hasTotal ? total : NSUIntegerMax);
	
	// Guard against divide by zero
	return (hasTotal ? ((float)done/(float)total) : NAN);
}

- (NSUInteger)_maximumReadLength {
	NSAssert(_terminator != nil, @"searching for nil terminator");
	
	if ([_terminator isKindOfClass:[NSNumber class]]) {
		return ([_terminator unsignedIntegerValue] - _bytesRead);
	}
	
	if ([_terminator isKindOfClass:[NSData class]]) {
		// What we're going to do is look for a partial sequence of the terminator at the end of the buffer.
		// If a partial sequence occurs, then we must assume the next bytes to arrive will be the rest of the term,
		// and we can only read that amount.
		// Otherwise, we're safe to read the entire length of the term.
		
		unsigned result = [_terminator length];
		
		// i = index within buffer at which to check data
		// j = length of term to check against
		
		// Note: Beware of implicit casting rules
		// This could give you -1: MAX(0, (0 - [term length] + 1));
		
		CFIndex i = MAX(0, (CFIndex)(_bytesRead - [_terminator length] + 1));
		CFIndex j = MIN([_terminator length] - 1, _bytesRead);
		
		while (i < _bytesRead) {
			const void *subBuffer = ([self.buffer bytes] + i);
			
			if (memcmp(subBuffer, [_terminator bytes], j) == 0) {
				result = [_terminator length] - j;
				break;
			}
			
			i++;
			j--;
		}
		
		return result;
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"Cannot determine the maximum read length.", nil];
	return 0;
}

- (BOOL)performRead:(CFReadStreamRef)readStream error:(NSError **)errorRef {
	BOOL packetComplete = NO;
	
	while (!packetComplete && CFReadStreamHasBytesAvailable(readStream)) {
		NSUInteger maximumReadLength = [self _maximumReadLength];
		NSUInteger bufferIncrement = (maximumReadLength - ([self.buffer length] - _bytesRead));
		[_buffer increaseLengthBy:bufferIncrement];
		
		CFIndex bytesToRead = ([self.buffer length] - _bytesRead);
		UInt8 *readBuffer = (UInt8 *)([_buffer mutableBytes] + _bytesRead);
		CFIndex bytesRead = CFReadStreamRead(readStream, readBuffer, bytesToRead);
		
		if (bytesRead < 0) {
			if (errorRef != NULL)
				*errorRef = AFErrorFromCFStreamError(CFReadStreamGetError(readStream));
			return NO;
		} else {
			_bytesRead += bytesRead;
		}
		
		if ([_terminator isKindOfClass:[NSData class]]) {
			// Done when we match the byte pattern
			int terminatorLength = [_terminator length];
			
			if (_bytesRead >= terminatorLength) {
				const void *buf = [self.buffer bytes] + (_bytesRead - terminatorLength);
				const void *seq = [_terminator bytes];
				
				packetComplete = (memcmp(buf, seq, terminatorLength) == 0);
			}
		} else {
			// Done when sized buffer is full.
			packetComplete = (_bytesRead == [self.buffer length]);
		}
	}
	
	return packetComplete;
}

@end
