//
//  AFPacketWriteFromReadStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFNetworkPacketWriteFromReadStream.h"

#import "AFNetwork-Functions.h"
#import "AFNetwork-Constants.h"

@interface AFNetworkPacketWriteFromReadStream ()
@property (readonly, nonatomic) NSInteger totalBytesToWrite;
@property (readonly, nonatomic) NSInteger bytesWritten;

@property (assign, nonatomic) NSInputStream *readStream;
@property (assign, nonatomic) BOOL readStreamOpened, readStreamClosed;
@end

@interface AFNetworkPacketWriteFromReadStream (AFNetworkPrivate)
- (BOOL)_tryOpenReadStream;
- (void)_tryCloseReadStream;
- (void)_postCompletionNotification:(NSNotification *)notification;
@end

@implementation AFNetworkPacketWriteFromReadStream

@synthesize totalBytesToWrite=_totalBytesToWrite, bytesWritten=_bytesWritten;
@synthesize readStream=_readStream, readStreamOpened=_readStreamOpened, readStreamClosed=_readStreamClosed;

@synthesize readStreamFilter=_readStreamFilter;

- (id)initWithTotalBytesToWrite:(NSInteger)totalBytesToWrite readStream:(NSInputStream *)readStream {
	NSParameterAssert(totalBytesToWrite != 0);
	NSParameterAssert(readStream != nil && [readStream streamStatus] == NSStreamStatusNotOpen);
	
	self = [self init];
	if (self == nil) return nil;
	
	_totalBytesToWrite = totalBytesToWrite;
	
	_bufferSize = (64 * 1024);
	_bufferSize = MIN(_bufferSize, totalBytesToWrite);
	
#if TARGET_OS_IPHONE
	_readBuffer = malloc(_bufferSize);
#else
	_readBuffer = NSAllocateCollectable(_bufferSize, 0);
#endif /* TARGET_OS_IPHONE */
	
	_readStream = [readStream retain];
	
	return self;
}

- (void)dealloc {
	[_readStream release];
	
	free(_readBuffer);
	
	[_readStreamFilter release];
	
	[super dealloc];
}

- (float)currentProgressWithBytesDone:(NSInteger *)bytesDone bytesTotal:(NSInteger *)bytesTotal {
	if (_totalBytesToWrite <= 0) {
		return [super currentProgressWithBytesDone:bytesDone bytesTotal:bytesTotal];
	}
	
	if (bytesDone != NULL) {
		*bytesDone = _bytesWritten;
	}
	if (bytesTotal != NULL) {
		*bytesTotal = _totalBytesToWrite;
	}
	return ((float)_bytesWritten / (float)_totalBytesToWrite);
}

- (NSInteger)performWrite:(NSOutputStream *)writeStream {
	if (![self _tryOpenReadStream]) {
		return -1;
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
			
			NSInteger bytesRead = [self.readStream read:_readBuffer maxLength:maximumReadSize];
			if (bytesRead < 0) {
				NSError *readStreamError = [self.readStream streamError];
				if (readStreamError == nil) {
					readStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
				}
				
				NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
												  readStreamError, AFNetworkPacketErrorKey,
												  nil];
				NSNotification *completionNotification = [NSNotification notificationWithName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
				
				[self _postCompletionNotification:completionNotification];
				return -1;
			}
			
			_bufferOffset = 0;
			_bufferLength = bytesRead;
			
			do {
				if (bytesRead <= 0) {
					break;
				}
				
				NSData * (^readStreamFilter)(NSData *) = self.readStreamFilter;
				if (readStreamFilter == nil) {
					break;
				}
				
				@autoreleasepool {
					NSData *readData = [NSData dataWithBytesNoCopy:_readBuffer length:_bufferLength freeWhenDone:NO];
					readData = readStreamFilter(readData);
					
					NSUInteger newBufferSize = [readData length];
					if (newBufferSize > _bufferSize) {
#if TARGET_OS_IPHONE
						_readBuffer = realloc(_readBuffer, newBufferSize);
#else
						_readBuffer = NSReallocateCollectable(_readBuffer, newBufferSize, 0);
#endif /* TARGET_OS_IPHONE */
					}
					
					[readData getBytes:_readBuffer length:newBufferSize];
					
					_bufferLength = newBufferSize;
				}
			} while (0);
		}
		
		/* Write */
		if (_bufferOffset < _bufferLength) {
			NSInteger bytesWritten = [writeStream write:(_readBuffer + _bufferOffset) maxLength:(_bufferLength - _bufferOffset)];
			if (bytesWritten < 0) {
				NSError *writeStreamError = [writeStream streamError];
				if (writeStreamError == nil) {
					writeStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
				}
				
				NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
												  writeStreamError, AFNetworkPacketErrorKey,
												  nil];
				NSNotification *completionNotification = [NSNotification notificationWithName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
				
				[self _postCompletionNotification:completionNotification];
				return -1;
			}
			
			currentBytesWritten += bytesWritten;
			_bytesWritten += bytesWritten;
			
			_bufferOffset += bytesWritten;
			
			if (_bufferOffset == _bufferLength) {
				_bufferOffset = 0;
				_bufferLength = 0;
			}
		}
		
		/* Check */
		if ((_bytesWritten == _totalBytesToWrite) ||
			(_bufferOffset == _bufferLength && _totalBytesToWrite == -1 && [self.readStream streamStatus] == NSStreamStatusAtEnd)) {
			[self _postCompletionNotification:[NSNotification notificationWithName:AFNetworkPacketDidCompleteNotificationName object:self]];
			break;
		}
	}
	
	return currentBytesWritten;
}

@end

@implementation AFNetworkPacketWriteFromReadStream (AFNetworkPrivate)

- (BOOL)_tryOpenReadStream {
	if (self.readStreamOpened) {
		return YES;
	}
	if (self.readStreamClosed) {
		return NO;
	}
	
	Boolean opened = CFReadStreamOpen((CFReadStreamRef)self.readStream);
	if (!opened) {
		NSError *readStreamError = [self.readStream streamError];
		if (readStreamError == nil) {
			readStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
		}
		
		NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  readStreamError, AFNetworkPacketErrorKey,
										  nil];
		NSNotification *completionNotification = [NSNotification notificationWithName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
		
		[self _postCompletionNotification:completionNotification];
		return NO;
	}
	
	// Note: we cannot steal the stream delegate
	do {
		// nop
	} while (CFReadStreamGetStatus((CFReadStreamRef)self.readStream) != kCFStreamStatusOpen && CFReadStreamGetStatus((CFReadStreamRef)self.readStream) != kCFStreamStatusError);
	
	self.readStreamOpened = YES;
	
	return YES;
}

- (void)_tryCloseReadStream {
	if (!self.readStreamOpened) {
		return;
	}
	if (self.readStreamClosed) {
		return;
	}
	
	CFReadStreamClose((CFReadStreamRef)self.readStream);
	
	self.readStreamClosed = YES;
}

- (void)_postCompletionNotification:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] postNotification:notification];
	
	[self _tryCloseReadStream];
}

@end
