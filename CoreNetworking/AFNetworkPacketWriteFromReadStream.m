//
//  AFPacketWriteFromReadStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFNetworkPacketWriteFromReadStream.h"

#import "AFNetworkFunctions.h"
#import "AFNetworkConstants.h"

@interface AFNetworkPacketWriteFromReadStream ()
@property (readonly) NSInteger totalBytesToWrite;
@property (readonly) NSInteger bytesWritten;

@property (assign) NSInputStream *readStream;
@property (assign) BOOL readStreamOpen;
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
	
	_bufferSize = (64 * 1024);
	
	_readBuffer = NSAllocateCollectable(_bufferSize, 0);
	
	_readStream = [readStream retain];
	
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

- (NSInteger)performWrite:(NSOutputStream *)writeStream {
	if (![self readStreamOpen]) {
		Boolean opened = CFReadStreamOpen((CFReadStreamRef)_readStream);
		
		if (!opened) {
			NSError *readStreamError = [[self readStream] streamError];
			if (readStreamError == nil) readStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
			
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  readStreamError, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return -1;
		}
		
		do {
			// nop
		} while (CFReadStreamGetStatus((CFReadStreamRef)_readStream) != kCFStreamStatusOpen && CFReadStreamGetStatus((CFReadStreamRef)_readStream) != kCFStreamStatusError);
		
		[self setReadStreamOpen:YES];
	}
	
	
	NSInteger currentBytesWritten = 0;
	
	while ([writeStream hasSpaceAvailable]) {
		/* Read */
		// Note: this is intentionally blocking
		if (_bufferLength == 0) {
			size_t maximumReadSize = _bufferSize;
			if (_totalBytesToWrite > 0) {
				maximumReadSize = MIN(maximumReadSize, (_totalBytesToWrite - _bytesWritten));
			}
			
			NSInteger bytesRead = [[self readStream] read:_readBuffer maxLength:maximumReadSize];
			if (bytesRead < 0) {
				NSError *readStreamError = [[self readStream] streamError];
				if (readStreamError == nil) readStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
				
				NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
												  readStreamError, AFNetworkPacketErrorKey,
												  nil];
				[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
				return -1;
			}
			
			_bufferLength = bytesRead;
			_bufferOffset = 0;
		}
		
		/* Write */
		{
			NSInteger bytesWritten = [writeStream write:(_readBuffer + _bufferOffset) maxLength:(_bufferLength - _bufferOffset)];
			if (bytesWritten < 0) {
				NSError *writeStreamError = [writeStream streamError];
				if (writeStreamError == nil) writeStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
				
				NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
												  writeStreamError, AFNetworkPacketErrorKey,
												  nil];
				[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
				return -1;
			}
			
			currentBytesWritten += bytesWritten;
			_bufferOffset += bytesWritten;
			
			if (_bufferOffset == _bufferLength) {
				_bufferLength = 0;
				_bufferOffset = 0;
			}
		}
		
		/* Check */
		if ((_bytesWritten == _totalBytesToWrite) || ((_bufferOffset == _bufferLength) && _totalBytesToWrite == -1 && [[self readStream] streamStatus] == NSStreamStatusAtEnd)) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:nil];
			break;
		}
	}
	
	return currentBytesWritten;
}

@end
