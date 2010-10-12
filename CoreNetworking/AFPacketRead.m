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

@interface AFPacketRead ()
@property (assign) NSUInteger bytesRead;
@property (copy) id terminator;
@end

@implementation AFPacketRead

@synthesize bytesRead=_bytesRead, buffer=_buffer, terminator=_terminator;

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
		[_buffer setLength:[_terminator integerValue]];
	}
	
	return self;
}

- (void)dealloc {
	[_buffer release];
	[_terminator release];
	
	[super dealloc];
}

- (float)currentProgressWithBytesDone:(NSUInteger *)bytesDone bytesTotal:(NSUInteger *)bytesTotal {	
	BOOL hasTotal = ([[self terminator] isKindOfClass:[NSNumber class]]);
	
	NSUInteger done = [self bytesRead];
	NSUInteger total = [[self buffer] length];
	
	if (bytesDone != NULL) *bytesDone = done;
	if (bytesTotal != NULL) *bytesTotal = (hasTotal ? total : NSUIntegerMax);
	
	// Guard against divide by zero
	return (hasTotal ? ((float)done/(float)total) : NAN);
}

- (NSUInteger)_maximumReadLength {
	NSParameterAssert([self terminator] != nil);
	
	if ([[self terminator] isEqual:[NSNull null]]) {
		NSUInteger bytes = 1024;
		[_buffer increaseLengthBy:bytes];
		return bytes;
	}
	
	if ([[self terminator] isKindOfClass:[NSNumber class]]) {
		return ([[self terminator] integerValue] - [self bytesRead]);
	}
	
	if ([[self terminator] isKindOfClass:[NSData class]]) {
		// What we're going to do is look for a partial sequence of the terminator at the end of the buffer.
		// If a partial sequence occurs, then we must assume the next bytes to arrive will be the rest of the term,
		// and we can only read that amount.
		// Otherwise, we're safe to read the entire length of the term.
		
		unsigned result = [[self terminator] length];
		
		// i = index within buffer at which to check data
		// j = length of term to check against
		
		// Note: Beware of implicit casting rules
		// This could give you -1: MAX(0, (0 - [term length] + 1));
		
		CFIndex i = MAX(0, (CFIndex)([self bytesRead] - [[self terminator] length] + 1));
		CFIndex j = MIN([[self terminator] length] - 1, [self bytesRead]);
		
		while (i < [self bytesRead]) {
			const void *subBuffer = ([[self buffer] bytes] + i);
			
			if (memcmp(subBuffer, [[self terminator] bytes], j) == 0) {
				result = [[self terminator] length] - j;
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
	
	if ([[self terminator] isKindOfClass:[NSNumber class]]) {
		return maximumReadLength;
	}
	
	if ([[self terminator] isKindOfClass:[NSData class]] ||
		[[self terminator] isEqual:[NSNull null]]) {
		[[self buffer] increaseLengthBy:maximumReadLength];
		return maximumReadLength;
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"%s, cannot increase the buffer for an unknown terminator.", __PRETTY_FUNCTION__, nil];
	return 0;
}

- (void)performRead:(NSInputStream *)readStream {
	while ([readStream hasBytesAvailable]) {
		NSUInteger maximumReadLength = [self _increaseBuffer];
		
		uint8_t *readBuffer = (uint8_t *)([[self buffer] mutableBytes] + [self bytesRead]);
		NSUInteger currentBytesRead = [readStream read:readBuffer maxLength:maximumReadLength];
		
		if (currentBytesRead < 0) {
#warning check if this error is reported by event to the stream delegate, making this redundant? also in AFPacketWrite
			NSError *error = [readStream streamError];
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  error, AFPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return;
		}
		
		[self setBytesRead:([self bytesRead] + currentBytesRead)];
		// Note: this re-scales the receiver for the NSNull case, where the buffer is increased an arbitrary amount
		[[self buffer] setLength:[self bytesRead]];
		
		BOOL packetComplete = NO;
		if ([[self terminator] isKindOfClass:[NSData class]]) {
			// Done when we match the byte pattern
			int terminatorLength = [[self terminator] length];
			
			if ([self bytesRead] >= terminatorLength) {
				void *buf = (uint8_t *)[[self buffer] bytes] + ([self bytesRead] - terminatorLength);
				void *seq = (uint8_t *)[[self terminator] bytes];
				
				packetComplete = (memcmp(buf, seq, terminatorLength) == 0);
			}
		} else {
			// Done when sized buffer is full
			packetComplete = ([self bytesRead] == [[self buffer] length]);
		}
		if (packetComplete) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
			break;
		}
		
		continue;
	}
}

@end
