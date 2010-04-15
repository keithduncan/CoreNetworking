//
//  AFPacketWriteFromReadStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFPacketWriteFromReadStream.h"

#import "AFPriorityProxy.h"

#import "AFPacketRead.h"
#import "AFPacketWrite.h"
#import "AFNetworkStream.h"
#import "AFNetworkFunctions.h"
#import "AFNetworkConstants.h"

// Note: this doesn't simply reuse the AFNetworkTransport with provided write and read streams since the base packets would read and then write the whole packet. This adaptor class minimises the memory footprint.

@interface AFPacketWriteFromReadStream ()
@property (readonly) NSInteger numberOfBytesToWrite;

@property (readonly) NSInputStream *readStream;
@property (readonly) NSMutableData *readBuffer;

@property (assign) NSOutputStream *writeStream;
@property (retain) AFPacketWrite *currentWrite;
@end

@interface AFPacketWriteFromReadStream (Private)
- (void)_scheduleStreams;
- (void)_unscheduleStreams;

- (void)_enqueueReadPacket;
- (void)_readPacketDidComplete:(NSNotification *)notification;
- (void)_enqueueWritePacket;
- (void)_writePacketDidComplete:(NSNotification *)notification;
@end

@implementation AFPacketWriteFromReadStream

@synthesize numberOfBytesToWrite=_numberOfBytesToWrite;
@synthesize readStream=_readStream, readBuffer=_readBuffer;
@synthesize writeStream=_writeStream, currentWrite=_currentWrite;

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration readStream:(NSInputStream *)readStream numberOfBytesToWrite:(NSInteger)numberOfBytesToWrite {
	NSParameterAssert(readStream != nil && [readStream streamStatus] == NSStreamStatusNotOpen);
	
	self = [self initWithContext:context timeout:duration];
	if (self == nil) return nil;
	
	_numberOfBytesToWrite = numberOfBytesToWrite;
	
	_readStream = readStream;
	[_readStream setDelegate:(id)self];
	
	return self;
}

- (void)dealloc {
	[_readBuffer release];
	[_currentWrite release];
	
	[super dealloc];
}

- (void)performWrite:(NSOutputStream *)writeStream {
	if (_writeStream == nil) {
		_writeStream = writeStream;
		
		[self _scheduleStreams];
		[self _enqueueReadPacket];
	}
	
	[[self currentWrite] performWrite:writeStream];
}

@end

@implementation AFPacketWriteFromReadStream (Private)

- (void)_scheduleStreams {
#warning this should schedule the inner write stream in the same manner as the parent transport layer, supporting dispatch queues
	[[self readStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[[self readStream] open];
	
	// Note: the write stream doesn't need to be scheduled, since it already is to get this message
}

- (void)_unscheduleStreams {
	[[self readStream] unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[[self readStream] close];
}

- (void)_enqueueReadPacket {
	if (_readBuffer != nil) return;
	
	size_t bufferSize = (32 * 1024);
	if (_numberOfBytesToWrite > 0) {
		bufferSize = MIN(_numberOfBytesToWrite, bufferSize);
	}
	
	_readBufferCapacity = bufferSize;
	[_readBuffer autorelease];
	_readBuffer = [[NSMutableData alloc] initWithCapacity:bufferSize];
	
	[self _performRead];
}

- (void)_performRead {
	if (![[self readStream] hasBytesAvailable]) return;
	
	[[self readStream] read:[_readBuffer mutableBytes] maxLength:(_readBufferCapacity - [readBuffer length])];
	if ([_readBuffer length] != _readBufferCapacity) return;
	
	
}

- (void)stream:(NSInputStream *)stream didReceiveEvent:(NSStreamEvent)event {
	if (event == NSStreamEventOpenCompleted) return;
	
	if (event == NSStreamEventHasBytesAvailable) {
		if (_readBuffer == nil) [self _enqueueRead];
		else [self _performRead];
	}
	
	if (event == NSStreamEventEndEncountered) {
		
	}
	
	if (event == NSStreamEventErrorOccurred) {
		
	}
}

- (void)networkStream:(AFNetworkReadStream *)readStream didRead:(id <AFPacketReading>)packet partialDataOfLength:(NSUInteger)partialLength totalBytes:(NSUInteger)totalLength {
	
}

- (void)networkStream:(AFNetworkStream *)stream didRead:(id <AFPacketReading>)packet {
	
}

- (void)_enqueueWritePacket {
	if ([self currentWrite] != nil || [self bufferedRead] == nil) return;
	
	AFPacketWrite *writePacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:[[self bufferedRead] buffer]] autorelease];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_writePacketDidComplete:) name:AFPacketDidCompleteNotificationName object:writePacket];
	[self setCurrentWrite:writePacket];
	
	[self setBufferedRead:nil];
	
	[writePacket performWrite:[self writeStream]];
	[self _enqueueReadPacket];
}

- (void)_writePacketDidComplete:(NSNotification *)notification {
	AFPacketWrite *packet = [notification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:packet];
	
	if ([[notification userInfo] objectForKey:AFPacketErrorKey] != nil) {
		[self _unscheduleStreams];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	[self setCurrentWrite:nil];
	[self _enqueueWritePacket];
	
	if (!(_numberOfBytesToWrite < 0 && [self readStreamComplete]) && _numberOfBytesToWrite != 0) return;
	
	[self _unscheduleStreams];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
}

- (void)networkStream:(AFNetworkStream *)stream didReceiveEvent:(NSStreamEvent)event {
	if (event == NSStreamEventEndEncountered) {
		[self setReadStreamComplete:YES];
		
		if ([self numberOfBytesToWrite] == -1 || [self numberOfBytesToWrite] == 0) return;
		
		
		[self _unscheduleStreams];
		
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   nil];
		NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:errorInfo];
		NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  error, AFPacketErrorKey,
										  nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
	}
}

- (void)networkStream:(AFNetworkStream *)stream didReceiveError:(NSError *)error {
	[self _unscheduleStreams];
	
	NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  error, AFPacketErrorKey,
									  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
}

@end
