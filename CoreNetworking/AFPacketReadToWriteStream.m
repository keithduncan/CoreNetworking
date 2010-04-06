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
@property (readonly) AFNetworkStream *writeStream;
@property (retain) AFPacketRead *currentRead;
@end

@interface AFPacketReadToWriteStream ()
- (void)_readPacketDidComplete:(NSNotification *)notification;
@end

@implementation AFPacketReadToWriteStream

@synthesize writeStream=_writeStream, currentRead=_currentRead;

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration writeStream:(NSOutputStream *)writeStream numberOfBytesToWrite:(NSInteger)numberOfBytesToWrite {
	NSParameterAssert([writeStream streamStatus] == NSStreamStatusNotOpen);
	
	self = [self initWithContext:context timeout:duration];
	if (self == nil) return nil;
	
	_numberOfBytesToWrite = numberOfBytesToWrite;
	
	_writeStream = [[AFNetworkWriteStream alloc] initWithStream:writeStream];
	[_writeStream setDelegate:self];
	
	return self;
}

- (void)dealloc {
	[_writeStream release];
	
	[_currentRead release];
	
	[super dealloc];
}

- (BOOL)performRead:(NSInputStream *)readStream error:(NSError **)errorRef {
	if (!_opened) {
#warning this should schedule the inner write stream in the same manner as the parent transport layer
		[[self writeStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
		[[self writeStream] open];
		
		_opened = YES;
	}
	
	do {
		if ([self currentRead] == nil) {
			size_t bufferSize = (32 * 1024);
			
			if (_numberOfBytesToWrite >= 0) {
				bufferSize = MIN(_numberOfBytesToWrite, bufferSize);
				_numberOfBytesToWrite -= bufferSize;
				
				if (bufferSize == 0) break;
			}
			
			AFPacketRead *readPacket = [[[AFPacketRead alloc] initWithContext:NULL timeout:-1 terminator:[NSNumber numberWithInteger:bufferSize]] autorelease];
			[self setCurrentRead:readPacket];
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:readPacket];
		}
		
		BOOL readSuccessful = [[self currentRead] performRead:readStream error:errorRef];
		if (!readSuccessful) return NO;
	} while ([self currentRead] == nil);
	
	return YES;
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	AFPacketRead *readPacket = [notification object];
	
	NSData *writeBuffer = readPacket.buffer;
	
	AFPacketWrite *writePacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:writeBuffer] autorelease];
	[[self writeStream] enqueueWrite:writePacket];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:readPacket];
	[self setCurrentRead:nil];
}

- (void)networkStream:(AFNetworkStream *)stream didReceiveError:(NSError *)error {
	NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  error, AFPacketErrorKey,
									  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
}

- (void)networkStream:(AFNetworkWriteStream *)stream didWrite:(id <AFPacketWriting>)packet {
	if (_numberOfBytesToWrite != 0 || [[self writeStream] countOfEnqueuedWrites] != 0) return;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
}

@end
