//
//  AFPacketRead.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkPacketRead.h"

#import "AFNetwork-Constants.h"
#import "AFNetwork-Functions.h"

@interface AFNetworkPacketRead ()
@property (assign, nonatomic) NSUInteger totalBytesRead;
@property (readwrite, copy, nonatomic) id terminator;
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
		NSParameterAssert([_terminator unsignedIntegerValue] > 0);
		[_buffer setLength:[_terminator unsignedIntegerValue]];
	}
	else if ([_terminator isKindOfClass:[NSData class]]) {
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
	
	NSUInteger done = [self totalBytesRead], total = [self.buffer length];
	
	if (bytesDone != NULL) {
		*bytesDone = done;
	}
	if (bytesTotal != NULL) {
		*bytesTotal = (hasTotal ? total : NSUIntegerMax);
	}
	
	if (!hasTotal) {
		return NAN;
	}
	
	return ((float)done/(float)total);
}

- (NSUInteger)_maximumReadLength {
	NSParameterAssert([self terminator] != nil);
	
	if ([[self terminator] isKindOfClass:[NSNumber class]]) {
		return ([[self terminator] unsignedIntegerValue] - [self totalBytesRead]);
	}
	else if ([[self terminator] isEqual:[NSNull null]]) {
		return (64 * 1024);
	}
	else if ([[self terminator] isKindOfClass:[NSData class]]) {
		NSUInteger maximumReadLength = 1;
		
		while (maximumReadLength < [[self terminator] length]) {
			NSData *partialTerminator = [[self terminator] subdataWithRange:NSMakeRange(0, maximumReadLength)];
			if ([[self buffer] rangeOfData:partialTerminator options:(NSDataSearchBackwards | NSDataSearchAnchored) range:NSMakeRange(0, [[self buffer] length])].location != NSNotFound) {
				break;
			}
			
			maximumReadLength++;
		}
		
		return maximumReadLength;
	}
	
	@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%s, cannot determine the maximum read length for an unknown terminator", __PRETTY_FUNCTION__] userInfo:nil];
	return 0;
}

- (uint8_t *)_mutableReadBuffer:(NSUInteger *)maximumReadLengthRef {
	NSParameterAssert(maximumReadLengthRef != NULL);
	
	/*
		Note
		
		the buffer length must be increased _before_ we caculate the write location
		
		NSMutableData may move it's internal buffer when resizing it
	 */
	NSUInteger maximumReadLength = [self _maximumReadLength];
	if ([[self terminator] isKindOfClass:[NSNumber class]]) {
		//nop
	}
	else if ([[self terminator] isEqual:[NSNull null]] || [[self terminator] isKindOfClass:[NSData class]]) {
		[[self buffer] increaseLengthBy:maximumReadLength];
	}
	else {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%s, cannot increase the buffer length for an unknown terminator", __PRETTY_FUNCTION__] userInfo:nil];
		return NULL;
	}
	*maximumReadLengthRef = maximumReadLength;
	
	return (uint8_t *)([[self buffer] mutableBytes] + [self totalBytesRead]);
}

- (NSInteger)performRead:(NSInputStream *)readStream {
	NSInteger currentBytesRead = 0;
	
	while ([readStream hasBytesAvailable]) {
		NSUInteger maximumReadLength = 0;
		uint8_t *readBuffer = [self _mutableReadBuffer:&maximumReadLength];
		
		NSInteger bytesRead = [readStream read:readBuffer maxLength:maximumReadLength];
		if (bytesRead < 0) {
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  [readStream streamError], AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return -1;
		}
		
		[self setTotalBytesRead:([self totalBytesRead] + bytesRead)];
		currentBytesRead += bytesRead;
		
		if ([[self terminator] isEqual:[NSNull null]] || [[self terminator] isKindOfClass:[NSData class]]) {
			[[self buffer] setLength:[self totalBytesRead]];
		}
		
		BOOL packetComplete = NO;
		if ([[self terminator] isKindOfClass:[NSNull class]] ||
			[[self terminator] isKindOfClass:[NSNumber class]]) {
			packetComplete = ([self totalBytesRead] == [[self buffer] length]);
		}
		else if ([[self terminator] isKindOfClass:[NSData class]]) {
			packetComplete = ([[self buffer] rangeOfData:[self terminator] options:(NSDataSearchBackwards | NSDataSearchAnchored) range:NSMakeRange(0, [[self buffer] length])].location != NSNotFound);
		}
		else {
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%s, cannot detect completion for an unknown terminator", __PRETTY_FUNCTION__] userInfo:nil];
			return -1;
		}
		
		if (packetComplete) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
			break;
		}
	}
	
	return currentBytesRead;
}

@end
