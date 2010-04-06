//
//  AFPacketRead.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFPacketRead.h"

#import "AFNetworkConstants.h"
#import "AFNetworkFunctions.h"

@implementation AFPacketRead

@synthesize buffer=_buffer;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_buffer = [[NSMutableData alloc] init];
	
	return self;
}

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration terminator:(id)terminator {
	self = [self initWithContext:context timeout:duration];
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
	
	[NSException raise:NSInternalInconsistencyException format:@"%s, cannot determine the maximum read length for an unknown terminator.", __PRETTY_FUNCTION__, nil];
	return 0;
}

- (NSUInteger)_increaseBuffer {
	NSUInteger maximumReadLength = [self _maximumReadLength];
	
	if ([_terminator isKindOfClass:[NSNumber class]]) {
		return maximumReadLength;
	}
	
	if ([_terminator isKindOfClass:[NSData class]]) {
		[_buffer increaseLengthBy:maximumReadLength];
		return maximumReadLength;
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"%s, cannot increase the buffer for an unknown terminator.", __PRETTY_FUNCTION__, nil];
	return 0;
}

- (void)performRead:(NSInputStream *)readStream {
	BOOL packetComplete = NO;
	
	while (!packetComplete && [readStream hasBytesAvailable]) {
		NSUInteger maximumReadLength = [self _increaseBuffer];
		
		uint8_t *readBuffer = (UInt8 *)([_buffer mutableBytes] + _bytesRead);
		NSUInteger bytesRead = [readStream read:readBuffer maxLength:maximumReadLength];
		
		if (bytesRead < 0) {
#warning check if this error is reported by event to the stream delegate, making this redundant? also in AFPacketWrite
			NSError *error = [readStream streamError];
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  error, AFPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return;
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
	
	if (packetComplete) [[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
}

@end
