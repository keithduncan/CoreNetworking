//
//  AFPacketReadToWriteStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFNetworkPacketReadToWriteStream.h"

#import "AFNetworkPacketRead.h"
#import "AFNetworkPacketWrite.h"
#import "AFNetworkFunctions.h"
#import "AFNetworkStream.h"

// Note: this doesn't simply reuse the AFNetworkTransport with provided write and read streams since the base packets would read and then write the whole packet. This adaptor class minimises the memory footprint.

@interface AFNetworkPacketReadToWriteStream () <AFNetworkWriteStreamDelegate>
@property (readonly) AFNetworkWriteStream *writeStream;
@property (retain) AFNetworkPacketRead *currentRead;
@end

@implementation AFNetworkPacketReadToWriteStream

@synthesize writeStream=_writeStream, currentRead=_currentRead;

- (id)initWithWriteStream:(NSOutputStream *)writeStream numberOfBytesToRead:(NSInteger)numberOfBytesToRead {
	NSParameterAssert(writeStream != nil && [writeStream streamStatus] == NSStreamStatusNotOpen);
	
	self = [self init];
	if (self == nil) return nil;
	
	_numberOfBytesToRead = numberOfBytesToRead;
	
	_writeStream = [[AFNetworkWriteStream alloc] initWithStream:writeStream];
	[_writeStream setDelegate:self];
	
	return self;
}

- (void)dealloc {
	[_writeStream release];
	
	[_currentRead release];
	
	[super dealloc];
}

- (void)performRead:(NSInputStream *)readStream {
	if (!_opened) {
#warning this should schedule the inner write stream in the same manner as the parent transport layer, supporting dispatch queues
		[[self writeStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
		[[self writeStream] open];
		
		_opened = YES;
	}
	
	NSUInteger bufferSize = (16 * 1024);
	bufferSize = MIN(_numberOfBytesToRead, bufferSize);
	uint8_t *readBuffer = malloc(bufferSize);
	
	NSMutableData *writeBuffer = [NSMutableData dataWithCapacity:bufferSize];
	
	while ([readStream hasBytesAvailable]) {
		NSInteger bytesRead = [readStream read:readBuffer maxLength:bufferSize];
		
		if (bytesRead < 0) {
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  [readStream streamError], AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			break;
		}
		
		[writeBuffer appendBytes:readBuffer length:bytesRead];
		_numberOfBytesToRead -= bytesRead;
	}
	
	AFNetworkPacketWrite *writePacket = [[[AFNetworkPacketWrite alloc] initWithData:writeBuffer] autorelease];
	[[self writeStream] enqueueWrite:writePacket];
	
	free(readBuffer);
}

- (void)networkStream:(AFNetworkStream *)stream didReceiveEvent:(NSStreamEvent)event {
	
}

- (void)networkStream:(AFNetworkStream *)stream didReceiveError:(NSError *)error {
	NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  error, AFNetworkPacketErrorKey,
									  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
}

- (void)networkStream:(AFNetworkWriteStream *)stream didWrite:(id <AFNetworkPacketWriting>)packet {
	if ([[self writeStream] countOfEnqueuedWrites] != 0) return;
	if (_numberOfBytesToRead != 0) return;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
}

@end
