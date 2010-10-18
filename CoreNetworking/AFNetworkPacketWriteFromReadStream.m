//
//  AFPacketWriteFromReadStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFNetworkPacketWriteFromReadStream.h"

#import "AFNetworkPacketRead.h"
#import "AFNetworkPacketWrite.h"
#import "AFNetworkStream.h"
#import "AFNetworkFunctions.h"
#import "AFNetworkConstants.h"

#define READ_BUFFER_SIZE (64 * 1024)

@interface AFNetworkPacketWriteFromReadStream ()
@property (readonly) NSInteger totalBytesToWrite;
@property (readonly) NSInteger bytesWritten;

@property (assign) NSInputStream *readStream;
@property (assign) BOOL readStreamOpen;
@end

@interface AFNetworkPacketWriteFromReadStream (Private)
- (void)_postReadStreamCompletionNotification;
@end

@implementation AFNetworkPacketWriteFromReadStream

@synthesize totalBytesToWrite=_totalBytesToWrite, bytesWritten=_bytesWritten;
@synthesize readStream=_readStream, readStreamOpen=_readStreamOpen;

- (id)initWithReadStream:(NSInputStream *)readStream totalBytesToWrite:(NSInteger)totalBytesToWrite {
	NSParameterAssert(readStream != nil && [readStream streamStatus] == NSStreamStatusNotOpen);
	NSParameterAssert(totalBytesToWrite != 0);
	
	self = [self init];
	if (self == nil) return nil;
	
	_totalBytesToWrite = totalBytesToWrite;
	
	_readStream = [readStream retain];
	[_readStream setDelegate:(id)self];
	
	_readBuffer = NSAllocateCollectable(READ_BUFFER_SIZE, 0);
	
	return self;
}

- (void)dealloc {
	[_readStream release];
	
	free(_readBuffer);
	
	[super dealloc];
}

- (float)currentProgressWithBytesDone:(NSUInteger *)bytesDone bytesTotal:(NSUInteger *)bytesTotal {
	if (_totalBytesToWrite < 0) return [super currentProgressWithBytesDone:bytesDone bytesTotal:bytesTotal];
	
	if (bytesDone != NULL) *bytesDone = _bytesWritten;
	if (bytesTotal != NULL) *bytesTotal = _totalBytesToWrite;
	
	return (_totalBytesToWrite > 0 ? ((float)_bytesWritten / (float)_totalBytesToWrite) : 0);
}

- (void)performWrite:(NSOutputStream *)writeStream {
	if (![self readStreamOpen]) {
		Boolean opened = CFReadStreamOpen((CFReadStreamRef)_readStream);
		
		if (!opened) {
			NSError *readStreamError = [[self readStream] streamError];
			if (readStreamError == nil) readStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
			
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  readStreamError, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return;
		}
		
		do {
			// nop
		} while (CFReadStreamGetStatus((CFReadStreamRef)_readStream) != kCFStreamStatusOpen && CFReadStreamGetStatus((CFReadStreamRef)_readStream) != kCFStreamStatusError);
		
		[self setReadStreamOpen:YES];
	}
	
	
	while ([writeStream hasSpaceAvailable]) {
		// Read
		if (_currentBufferLength == 0) {
			size_t maximumReadSize = READ_BUFFER_SIZE;
			if (_totalBytesToWrite > 0) {
				maximumReadSize = MIN((_totalBytesToWrite - _bytesWritten), maximumReadSize);
				_bytesWritten += maximumReadSize;
			}
			
			// Note: this is intentionally blocking
			_currentBufferOffset = 0;
			_currentBufferLength = [[self readStream] read:_readBuffer maxLength:maximumReadSize];
			
			if (_currentBufferLength <= 0) {
				[self _postReadStreamCompletionNotification];
				return;
			}
		}
		
		// Write
		{
			_currentBufferOffset += [writeStream write:(_readBuffer + _currentBufferOffset) maxLength:(_currentBufferLength - _currentBufferOffset)];
			
			if (_currentBufferOffset == _currentBufferLength) {
				_currentBufferLength = 0;
			}
		}
	}
}

- (void)_postReadStreamCompletionNotification {
	NSError *readStreamError = nil;
	if ([[self readStream] streamStatus] == NSStreamStatusError) readStreamError = [[self readStream] streamError];
	
	NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  readStreamError, AFNetworkPacketErrorKey,
									  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
}

@end

#undef READ_BUFFER_SIZE
