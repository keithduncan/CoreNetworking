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
@property (readonly) NSInteger numberOfBytesToWrite;

@property (assign) NSInputStream *readStream;
@property (assign) BOOL readStreamOpen;
@end

@interface AFNetworkPacketWriteFromReadStream (Private)
- (void)_postReadStreamCompletionNotification;
@end

@implementation AFNetworkPacketWriteFromReadStream

@synthesize numberOfBytesToWrite=_numberOfBytesToWrite;
@synthesize readStream=_readStream, readStreamOpen=_readStreamOpen;

- (id)initWithReadStream:(NSInputStream *)readStream numberOfBytesToWrite:(NSInteger)numberOfBytesToWrite {
	NSParameterAssert(readStream != nil && [readStream streamStatus] == NSStreamStatusNotOpen);
	NSParameterAssert(numberOfBytesToWrite != 0);
	
	self = [self init];
	if (self == nil) return nil;
	
	_numberOfBytesToWrite = numberOfBytesToWrite;
	
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
	
	
	do {
		if (_currentBufferLength == 0) {
			size_t maximumReadSize = READ_BUFFER_SIZE;
			if (_numberOfBytesToWrite > 0) {
				maximumReadSize = MIN(_numberOfBytesToWrite, maximumReadSize);
				_numberOfBytesToWrite -= maximumReadSize;
			}
			
			_currentBufferOffset = 0;
			_currentBufferLength = [[self readStream] read:_readBuffer maxLength:maximumReadSize];
			
			if (_currentBufferLength <= 0) {
				[self _postReadStreamCompletionNotification];
				return;
			}
		}
		
		_currentBufferOffset += [writeStream write:(_readBuffer + _currentBufferOffset) maxLength:(_currentBufferLength - _currentBufferOffset)];
		
		if (_currentBufferOffset == _currentBufferLength) {
			_currentBufferLength = 0;
		}
	} while ([writeStream hasSpaceAvailable]);
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
