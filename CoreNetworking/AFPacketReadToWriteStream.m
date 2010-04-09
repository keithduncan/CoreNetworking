//
//  AFPacketReadToWriteStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFPacketReadToWriteStream.h"

#import "AFPacket.h"
#import "AFPacketRead.h"
#import "AFPacketWrite.h"
#import "AFNetworkFunctions.h"
#import "AFNetworkStream.h"

// Note: this doesn't simply reuse the AFNetworkTransport with provided write and read streams since the base packets would read and then write the whole packet. This adaptor class minimises the memory footprint.

@interface AFPacketReadToWriteStream () <AFNetworkWriteStreamDelegate>
@property (readonly) AFNetworkWriteStream *writeStream;
@property (retain) AFPacketRead *currentRead;
@end

@implementation AFPacketReadToWriteStream

@synthesize writeStream=_writeStream, currentRead=_currentRead;

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration writeStream:(NSOutputStream *)writeStream numberOfBytesToRead:(NSInteger)numberOfBytesToRead {
	NSParameterAssert(writeStream != nil && [writeStream streamStatus] == NSStreamStatusNotOpen);
	
	self = [self initWithContext:context timeout:duration];
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
	
	CFIndex bytesRead = 0;
	const uint8_t *buffer = CFReadStreamGetBuffer((CFReadStreamRef)readStream, _numberOfBytesToRead, &bytesRead);
	NSParameterAssert(buffer != NULL);
	
	_numberOfBytesToRead -= bytesRead;
	
	NSData *bufferData = [NSData dataWithBytes:buffer length:bytesRead];
	AFPacketWrite *writePacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:bufferData] autorelease];
	[[self writeStream] enqueueWrite:writePacket];
}

- (void)networkStream:(AFNetworkStream *)stream didReceiveError:(NSError *)error {
	NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  error, AFPacketErrorKey,
									  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
}

- (void)networkStream:(AFNetworkWriteStream *)stream didWrite:(id <AFPacketWriting>)packet {
	if ([[self writeStream] countOfEnqueuedWrites] != 0) return;
	if (_numberOfBytesToRead != 0) return;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
}

@end
