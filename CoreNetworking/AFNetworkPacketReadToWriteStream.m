//
//  AFPacketReadToWriteStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFNetworkPacketReadToWriteStream.h"

#import "AFNetworkFunctions.h"
#import "AFNetworkConstants.h"

// Note: this doesn't simply reuse the AFNetworkTransport with provided write and read streams since the base packets would read and then write the whole packet. This adaptor class minimises the memory footprint.

@interface AFNetworkPacketReadToWriteStream ()
@property (assign) NSInteger totalBytesToRead;
@property (assign) NSInteger bytesRead;

@property (assign) NSOutputStream *writeStream;
@property (assign) BOOL writeStreamOpen;
@end

@implementation AFNetworkPacketReadToWriteStream

@synthesize totalBytesToRead=_totalBytesToRead, bytesRead=_bytesRead, writeStream=_writeStream, writeStreamOpen=_writeStreamOpen;

- (id)initWithWriteStream:(NSOutputStream *)writeStream totalBytesToRead:(NSInteger)totalBytesToRead {
	NSParameterAssert(writeStream != nil && [writeStream streamStatus] == NSStreamStatusNotOpen);
	NSParameterAssert(totalBytesToRead != 0);
	
	self = [self init];
	if (self == nil) return nil;
	
	_totalBytesToRead = totalBytesToRead;
	
	_bufferSize = (64 * 1024);
	_bufferSize = MIN(_bufferSize, _totalBytesToRead);
	
	_readBuffer = NSAllocateCollectable(_bufferSize, 0);
	
	_writeStream = [writeStream retain];
	
	return self;
}

- (void)dealloc {
	[_writeStream release];
	
	free(_readBuffer);
	
	[super dealloc];
}

- (float)currentProgressWithBytesDone:(NSUInteger *)bytesDone bytesTotal:(NSUInteger *)bytesTotal {
	if (_totalBytesToRead < 0) return [super currentProgressWithBytesDone:bytesDone bytesTotal:bytesTotal];
	
	if (bytesDone != NULL) *bytesDone = _bytesRead;
	if (bytesTotal != NULL) *bytesTotal = _totalBytesToRead;
	return ((float)_bytesRead / (float)_totalBytesToRead);
}

- (NSInteger)performRead:(NSInputStream *)readStream {
	if (![self writeStreamOpen]) {
		Boolean opened = CFWriteStreamOpen((CFWriteStreamRef)[self writeStream]);
		
		if (!opened) {
			NSError *writeStreamError = [[self writeStream] streamError];
			if (writeStreamError == nil) writeStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
			
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  writeStreamError, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return -1;
		}
		
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
			if (readStreamError == nil) readStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
			
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  readStreamError, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return -1;
		}
		
		currentBytesRead += bytesRead;
		_bytesRead += bytesRead;
		
		/* Write */
		// Note: this is intentionally blocking
		NSUInteger currentBytesWritten = 0;
		while (currentBytesWritten < bytesRead) {
			NSInteger bytesWritten = [[self writeStream] write:(_readBuffer + currentBytesWritten) maxLength:(bytesRead - currentBytesWritten)];
			if (bytesWritten < 0) {
				NSError *writeStreamError = [[self writeStream] streamError];
				if (writeStreamError == nil) writeStreamError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
				
				NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
												  writeStreamError, AFNetworkPacketErrorKey,
												  nil];
				[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
				return -1;
			}
			
			currentBytesWritten += bytesWritten;
		}
		
		/* Check */
		if ((_bytesRead == _totalBytesToRead) || (_totalBytesToRead == -1 && [[self writeStream] streamStatus] == NSStreamStatusAtEnd)) {
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
			break;
		}
	}
	
	return currentBytesRead;
}

@end
