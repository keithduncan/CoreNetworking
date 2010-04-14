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

// Note: this doesn't simply reuse the AFNetworkTransport with provided write and read streams since the base packets would read and then write the whole packet. This adaptor class minimises the memory footprint.

@interface AFPacketWriteFromReadStream ()
@property (readonly) AFNetworkReadStream *readStream;
@property (assign) BOOL readStreamDidEnd;

@property (readonly) id originalWriteStreamDelegate;
@property (readonly) NSOutputStream *originalWriteStream;
@property (readonly) AFNetworkWriteStream *writeStream;
@end

@interface AFPacketWriteFromReadStream (Private)
- (void)_scheduleStreams;
- (void)_unscheduleStreams;

- (void)_enqueueReadPacket;
- (void)_readPacketDidComplete:(NSNotification *)notification;
- (void)_writePacketDidComplete:(NSNotification *)notification;
@end

@implementation AFPacketWriteFromReadStream

@synthesize readStream=_readStream, readStreamDidEnd=_readStreamDidEnd, originalWriteStreamDelegate=_originalWriteStreamDelegate, originalWriteStream=_originalWriteStream, writeStream=_writeStream;

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration readStream:(NSInputStream *)readStream numberOfBytesToWrite:(NSInteger)numberOfBytesToWrite {
	NSParameterAssert(readStream != nil && [readStream streamStatus] == NSStreamStatusNotOpen);
	
	self = [self initWithContext:context timeout:duration];
	if (self == nil) return nil;
	
	_numberOfBytesToWrite = numberOfBytesToWrite;
	
	_readStream = [[AFNetworkReadStream alloc] initWithStream:readStream];
	[_readStream setDelegate:(id)self];
	
	return self;
}

- (void)dealloc {
	[_readStream release];
	[_writeStream release];
	
	[super dealloc];
}

- (AFPriorityProxy *)delegateProxy:(AFPriorityProxy *)proxy {
	if ([self originalWriteStreamDelegate] == nil) return proxy;
	
	if (proxy == nil) proxy = [[[AFPriorityProxy alloc] init] autorelease];
	
	if ([[self originalWriteStreamDelegate] respondsToSelector:@selector(delegateProxy:)]) proxy = [(id)[self originalWriteStreamDelegate] delegateProxy:proxy];
	[proxy insertTarget:[self originalWriteStreamDelegate]];
	
	return proxy;
}

- (void)performWrite:(NSOutputStream *)writeStream {
	// Note: because we hijack the stream's delegate, this is only called once
	
	if (!_opened) {
		[self _scheduleStreams];
		
		_originalWriteStreamDelegate = [writeStream delegate];
		_originalWriteStream = writeStream;
		
		_writeStream = [[AFNetworkWriteStream alloc] initWithStream:writeStream];
		[_writeStream setDelegate:(id)self];
		
		_opened = YES;
	}
	
	[self _enqueueReadPacket];
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
	
	[[self writeStream] setDelegate:(id)[self originalWriteStreamDelegate]];
	[(id)[self originalWriteStreamDelegate] stream:[self originalWriteStream] handleEvent:NSStreamEventHasSpaceAvailable];
}

- (void)_enqueueReadPacket {
	size_t bufferSize = (32 * 1024);
	if (_numberOfBytesToWrite >= 0) {
		bufferSize = MIN(_numberOfBytesToWrite, bufferSize);
		_numberOfBytesToWrite -= bufferSize;
		
		if (bufferSize == 0) return;
	}
	
	AFPacketRead *readPacket = [[[AFPacketRead alloc] initWithContext:NULL timeout:-1 terminator:[NSNumber numberWithInteger:bufferSize]] autorelease];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:readPacket];
	
	[[self readStream] enqueueRead:readPacket];
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	AFPacketRead *readPacket = [notification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:readPacket];
	
	if ([[notification userInfo] objectForKey:AFPacketErrorKey] != nil) {
		[self _unscheduleStreams];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		
		return;
	}
	
	AFPacketWrite *writePacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:[readPacket buffer]] autorelease];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_writePacketDidComplete:) name:AFPacketDidCompleteNotificationName object:writePacket];
	[[self writeStream] enqueueWrite:writePacket];
	
	[self _enqueueReadPacket];
}

// Note: these prevents the message being sent to the transport layer

- (void)networkStream:(AFNetworkReadStream *)readStream didRead:(id <AFPacketReading>)packet partialDataOfLength:(NSUInteger)partialLength totalBytes:(NSUInteger)totalLength {
	
}

- (void)networkStream:(AFNetworkStream *)stream didRead:(id <AFPacketReading>)packet {
	
}

- (void)networkStream:(AFNetworkWriteStream *)readStream didWrite:(id <AFPacketReading>)packet partialDataOfLength:(NSUInteger)partialLength totalBytes:(NSUInteger)totalLength {
	
}

- (void)networkStream:(AFNetworkStream *)stream didWrite:(id <AFPacketWriting>)packet {
	if ([[self writeStream] countOfEnqueuedWrites] != 0) return;
	if (!(_numberOfBytesToWrite < 0 && [self readStreamDidEnd]) && _numberOfBytesToWrite != 0) return;
	
	[self _unscheduleStreams];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
}

- (void)networkStream:(AFNetworkStream *)stream didReceiveEvent:(NSStreamEvent)event {
	if (stream != [self readStream]) {
		id delegate = [self delegateProxy:nil];
		if ([delegate respondsToSelector:_cmd]) [delegate networkStream:stream didReceiveEvent:event];
		return;
	}
	
	if (event == NSStreamEventEndEncountered) [self setReadStreamDidEnd:YES];
}

- (void)networkStream:(AFNetworkStream *)stream didReceiveError:(NSError *)error {
	[self _unscheduleStreams];
		
	NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  error, AFPacketErrorKey,
									  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
	
#warning do we need to forward write stream errors to the originalWriteStreamDelegate?
}

- (void)_writePacketDidComplete:(NSNotification *)notification {
	AFPacketWrite *packet = [notification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:packet];
	
	if ([[notification userInfo] objectForKey:AFPacketErrorKey] != nil) {
		[self _unscheduleStreams];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
	}
}

@end
