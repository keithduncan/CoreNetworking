//
//  AFPacketReadToWriteStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFNetworkPacketReadToWriteStream.h"

#import "AFNetwork-Functions.h"
#import "AFNetwork-Constants.h"

// Note: this doesn't simply reuse the AFNetworkTransport with provided write and read streams since the base packets would read and then write the whole packet. This adaptor class minimises the memory footprint.

@interface AFNetworkPacketReadToWriteStream ()
@property (assign, nonatomic) NSInteger totalBytesToRead;
@property (assign, nonatomic) NSInteger bytesRead;

@property (assign, nonatomic) NSOutputStream *writeStream;
@property (assign, nonatomic) BOOL writeStreamOpen;
@end

@implementation AFNetworkPacketReadToWriteStream

@synthesize totalBytesToRead=_totalBytesToRead, bytesRead=_bytesRead, writeStream=_writeStream, writeStreamOpen=_writeStreamOpen;

- (id)initWithTotalBytesToRead:(NSInteger)totalBytesToRead writeStream:(NSOutputStream *)writeStream {
	NSParameterAssert(writeStream != nil && [writeStream streamStatus] == NSStreamStatusNotOpen);
	NSParameterAssert(totalBytesToRead != 0);
	
	self = [self init];
	if (self == nil) return nil;
	
	_totalBytesToRead = totalBytesToRead;
	
	_bufferSize = (64 * 1024);
	_bufferSize = MIN(_bufferSize, _totalBytesToRead);
	
#if TARGET_OS_IPHONE
	_readBuffer = malloc(_bufferSize);
#else
	_readBuffer = NSAllocateCollectable(_bufferSize, 0);
#endif /* TARGET_OS_IPHONE */
	
	_writeStream = [writeStream retain];
	
	return self;
}

- (void)dealloc {
	[_writeStream release];
	
	free(_readBuffer);
	
	[super dealloc];
}

- (float)currentProgressWithBytesDone:(NSInteger *)bytesDone bytesTotal:(NSInteger *)bytesTotal {
	if (_totalBytesToRead < 0) {
		return [super currentProgressWithBytesDone:bytesDone bytesTotal:bytesTotal];
	}
	
	if (bytesDone != NULL) {
		*bytesDone = _bytesRead;
	}
	if (bytesTotal != NULL) {
		*bytesTotal = _totalBytesToRead;
	}
	return ((float)_bytesRead / (float)_totalBytesToRead);
}

- (NSInteger)performRead:(NSInputStream *)readStream {
	if (![self writeStreamOpen]) {
		Boolean opened = CFWriteStreamOpen((CFWriteStreamRef)[self writeStream]);
		if (!opened) {
			NSError *writeStreamError = [[self writeStream] streamError];
			if (writeStreamError == nil) {
				writeStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
			}
			
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  writeStreamError, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return -1;
		}
		
		// Note: we cannot steal the delegate of the stream
		do {
			// nop
		} while (CFWriteStreamGetStatus((CFWriteStreamRef)_writeStream) != kCFStreamStatusOpen && CFWriteStreamGetStatus((CFWriteStreamRef)_writeStream) != kCFStreamStatusError);
		
		[self setWriteStreamOpen:YES];
	}
	
	
	NSInteger currentBytesRead = 0;
	
	while ([readStream hasBytesAvailable]) {
		/* Read */
		NSInteger bytesRead = [readStream read:_readBuffer maxLength:MIN(_bufferSize, (_totalBytesToRead - _bytesRead))];
		if (bytesRead < 0) {
			NSError *readStreamError = [readStream streamError];
			if (readStreamError == nil) {
				readStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
			}
			
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  readStreamError, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return -1;
		}
		
		/* Write */
		// Note: this is intentionally blocking
		NSUInteger currentBytesWritten = 0;
		while (currentBytesWritten < bytesRead) {
			NSInteger bytesWritten = [[self writeStream] write:(_readBuffer + currentBytesWritten) maxLength:(bytesRead - currentBytesWritten)];
			if (bytesWritten < 0) {
				NSError *writeStreamError = [[self writeStream] streamError];
				if (writeStreamError == nil) {
					writeStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
				}
				
				NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
												  writeStreamError, AFNetworkPacketErrorKey,
												  nil];
				[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
				return -1;
			}
			
			currentBytesWritten += bytesWritten;
		}
		
		currentBytesRead += bytesRead;
		_bytesRead += bytesRead;
		
		/* Check */
		if ((_totalBytesToRead == _bytesRead) ||
			(_totalBytesToRead == -1 && ([readStream streamStatus] == NSStreamStatusAtEnd || [readStream streamStatus] == NSStreamStatusClosed))) {
			CFWriteStreamClose((CFWriteStreamRef)[self writeStream]);
			
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
			break;
		}
	}
	
	return currentBytesRead;
}

@end
