//
//  AFPacketRead.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkPacketRead.h"

#import "AFNetworkConstants.h"
#import "AFNetworkFunctions.h"

@interface AFNetworkPacketRead ()
@property (assign) NSUInteger totalBytesRead;
@property (copy) id terminator;
@end

@implementation AFNetworkPacketRead

@synthesize totalBytesRead=_totalBytesRead, buffer=_buffer, terminator=_terminator;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_buffer = [[NSMutableData alloc] init];
	
	return self;
}

- (id)initWithTerminator:(id)terminator {
	self = [self init];
	if (self == nil) return nil;
	
	_terminator = [terminator copy];
	
	if ([_terminator isKindOfClass:[NSNumber class]]) {
		NSParameterAssert([_terminator integerValue] > 0);
		[_buffer setLength:[_terminator integerValue]];
	}
	if ([_terminator isKindOfClass:[NSData class]]) {
		NSParameterAssert([_terminator length] > 0);
	}
	
	return self;
}

- (void)dealloc {
	[_buffer release];
	[_terminator release];
	
	[super dealloc];
}

- (float)currentProgressWithBytesDone:(NSInteger *)bytesDone bytesTotal:(NSInteger *)bytesTotal {	
	BOOL hasTotal = ([[self terminator] isKindOfClass:[NSNumber class]]);
	
	NSUInteger done = [self totalBytesRead];
	NSUInteger total = [[self buffer] length];
	
	if (bytesDone != NULL) *bytesDone = done;
	if (bytesTotal != NULL) *bytesTotal = (hasTotal ? total : NSUIntegerMax);
	
	// Guard against divide by zero
	return (hasTotal ? ((float)done/(float)total) : NAN);
}

- (NSUInteger)_maximumReadLength {
	NSParameterAssert([self terminator] != nil);
	
	if ([[self terminator] isEqual:[NSNull null]]) {
		return (64 * 1024);
	}
	
	if ([[self terminator] isKindOfClass:[NSNumber class]]) {
		return ([[self terminator] integerValue] - [self totalBytesRead]);
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
		
		CFIndex i = MAX(0, (CFIndex)([self totalBytesRead] - [[self terminator] length] + 1));
		CFIndex j = MIN([[self terminator] length] - 1, [self totalBytesRead]);
		
		while (i < [self totalBytesRead]) {
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

- (NSInteger)performRead:(NSInputStream *)readStream {
	NSInteger currentBytesRead = 0;
	
	while ([readStream hasBytesAvailable]) {
		NSUInteger maximumReadLength = [self _increaseBuffer];
		
		uint8_t *readBuffer = (uint8_t *)([[self buffer] mutableBytes] + [self totalBytesRead]);
		NSUInteger bytesRead = [readStream read:readBuffer maxLength:maximumReadLength];
		
		if (bytesRead < 0) {
#warning check if this error is reported by event to the stream delegate, making this redundant? also in AFPacketWrite
			NSError *error = [readStream streamError];
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  error, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return -1;
		}
		
		[self setTotalBytesRead:([self totalBytesRead] + bytesRead)];
		currentBytesRead += bytesRead;
		
		if ([[self terminator] isEqual:[NSNull null]]) {
			[[self buffer] setLength:[self totalBytesRead]];
		}
		
		BOOL packetComplete = NO;
		if ([[self terminator] isKindOfClass:[NSData class]]) {
			// Done when we match the byte pattern
			int terminatorLength = [[self terminator] length];
			
			if ([self totalBytesRead] >= terminatorLength) {
				void *buf = (uint8_t *)[[self buffer] bytes] + ([self totalBytesRead] - terminatorLength);
				void *seq = (uint8_t *)[[self terminator] bytes];
				
				packetComplete = (memcmp(buf, seq, terminatorLength) == 0);
			}
		} else {
			// Done when sized buffer is full
			packetComplete = ([self totalBytesRead] == [[self buffer] length]);
		}
		if (packetComplete) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
			break;
		}
		
		continue;
	}
	
	return currentBytesRead;
}

@end
