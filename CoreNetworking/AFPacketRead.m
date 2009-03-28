//
//  AFPacketRead.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFPacketRead.h"

#import "AFNetworkConstants.h"

#define READALL_CHUNKSIZE	256         // Incremental increase in buffer size

@implementation AFPacketRead

@synthesize buffer=_buffer;

- (id)init {
	[super init];
	
	_buffer = [[NSMutableData alloc] init];
	
	return self;
}

- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration terminator:(id)terminator {
	[self initWithTag:tag timeout:duration];
	
	if ([terminator isKindOfClass:[NSNumber class]]) {
		_maximumLength = [terminator unsignedIntegerValue];
		[_buffer setLength:_maximumLength];
		
		_terminator = nil;
	} else if ([terminator isKindOfClass:[NSData class]]) {
		_maximumLength = -1;
		_terminator = [terminator copy];
	}
	
	return self;
}

- (id)initWithTag:(NSUInteger)tag timeout:(NSTimeInterval)duration readAllAvailable:(BOOL)readAllAvailable {
	[self initWithTag:tag timeout:duration];
	
	_readAllAvailable = readAllAvailable;
	
	return self;
}

- (void)dealloc {
	[_buffer release];
	[_terminator release];
	
	[super dealloc];
}

- (void)progress:(float *)fraction done:(NSUInteger *)bytesDone total:(NSUInteger *)bytesTotal {
	// It's only possible to know the progress of our read if we're reading to a certain length
		// If we're reading to data, we don't know when the data pattern will arrive
		// If we're reading to timeout, then we have no idea when the next chunk of data will arrive.
	BOOL hasTotal = (_maximumLength > 0);
	
	NSUInteger done = _bytesRead;
	NSUInteger total = [self.buffer length];
	
	if (fraction != NULL) {
		if (hasTotal) {
			*fraction = (float)done/(float)total;
		} else /* Guard against divide by zero */ {
			*fraction = NAN;
		}
	}
	
	if (bytesDone != NULL) *bytesDone = done;
	if (bytesTotal != NULL) *bytesTotal = total;
}

/**
 * For read packets with a set terminator, returns the safe length of data that can be read
 * without going over a terminator, or the maxLength.
 * 
 * It is assumed the terminator has not already been read.
 **/
- (NSUInteger)_readLengthForTerminator {
	NSAssert(_terminator != nil, @"searching for nil terminator in data");
	
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
	
	return (_maximumLength > 0) ? MIN(result, (_maximumLength - _bytesRead)) : result;
}

- (BOOL)performRead:(CFReadStreamRef)readStream error:(NSError **)error {
	CFIndex currentTotalBytesRead = 0;
	
	BOOL packetComplete = NO;
	BOOL readStreamError = NO, maxoutError = NO;
	
	while (!packetComplete && !readStreamError && !maxoutError && CFReadStreamHasBytesAvailable(readStream)) {
		// If reading all available data, make sure there's room in the packet buffer.
		if (_readAllAvailable) {
			// Make sure there is at least READALL_CHUNKSIZE bytes available.
			// We don't want to increase the buffer any more than this or we'll waste space.
			unsigned int bufferIncrement = (READALL_CHUNKSIZE - ([self.buffer length] - _bytesRead));
			[_buffer increaseLengthBy:bufferIncrement];
		}
		
		// Number of bytes to read is space left in packet buffer
		CFIndex bytesToRead = ([self.buffer length] - _bytesRead);
		
		// Read data into packet buffer
		UInt8 *readBuffer = (UInt8 *)([_buffer mutableBytes] + _bytesRead);
		CFIndex bytesRead = CFReadStreamRead(readStream, readBuffer, bytesToRead);
		
		if (bytesRead < 0) {
			readStreamError = YES;
		} else {
			_bytesRead += bytesRead;
			currentTotalBytesRead += bytesRead;
		}
		
		// Is packet done?
		if (!_readAllAvailable) {
			if (_terminator != nil) {
				// Done when we match the byte pattern
				
				int terminatorLength = [_terminator length];
				
				if (_bytesRead >= terminatorLength) {
					const void *buf = [self.buffer bytes] + (_bytesRead - terminatorLength);
					const void *seq = [_terminator bytes];
					
					packetComplete = (memcmp(buf, seq, terminatorLength) == 0);
				}
			} else {
				// Done when sized buffer is full.
				packetComplete = ([self.buffer length] == _bytesRead);
			}
		} else if (_readAllAvailable) {
			// Doesn't end until everything is read
		}
		
		if (!packetComplete && _maximumLength >= 0 && _bytesRead >= _maximumLength) {
			// There's a set maxLength, and we've reached that maxLength without completing the read
			maxoutError = YES;
		}
	}
	
	if (_readAllAvailable && _bytesRead > 0) packetComplete = YES;
	
#warning perhaps errors should be returned in a collection
	if (readStreamError) {
		*error = [self errorFromCFStreamError:CFReadStreamGetError(readStream)];
	} else if (maxoutError) {
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedStringWithDefaultValue(@"AFSocketReadMaxedOutError", @"AFSocket", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Read operation reached set maximum length", nil), NSLocalizedDescriptionKey,
							  nil];
		
		*error = [NSError errorWithDomain:AFNetworkingErrorDomain code:AFPacketMaxedOutError userInfo:info];
	}
	
	return packetComplete;
}

@end

#undef READALL_CHUNKSIZE
