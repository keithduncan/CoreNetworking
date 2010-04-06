//
//  AFPacketWriteFromReadStream.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFPacketWriteFromReadStream.h"

#import "AFPacketRead.h"
#import "AFPacketWrite.h"
#import "AFNetworkStream.h"
#import "AFNetworkFunctions.h"

// Note: this doesn't simply reuse the AFNetworkTransport with provided write and read streams since the base packets would read and then write the whole packet. This adaptor class minimises the memory footprint.

@interface AFPacketWriteFromReadStream () <AFNetworkReadStreamDelegate>
@property (readonly) AFNetworkReadStream *readStream;
@property (retain) AFPacketRead *currentRead;
@property (retain) AFPacketWrite *currentWrite;
@end

@implementation AFPacketWriteFromReadStream

@synthesize readStream=_readStream, currentRead=_currentRead, currentWrite=_currentWrite;

- (id)initWithContext:(void *)context timeout:(NSTimeInterval)duration readStream:(NSInputStream *)readStream numberOfBytesToRead:(NSInteger)numberOfBytesToRead {
	NSParameterAssert([readStream streamStatus] == NSStreamStatusNotOpen);
	
	self = [self initWithContext:context timeout:duration];
	if (self == nil) return nil;
	
	_numberOfBytesToRead = numberOfBytesToRead;
	
	_readStream = [[AFNetworkReadStream alloc] initWithStream:readStream];
	[_readStream setDelegate:self];
	
	return self;
}

- (void)dealloc {
	[_readStream release];

	[_currentRead release];
	[_currentWrite release];
	
	[super dealloc];
}

- (void)performWrite:(NSOutputStream *)writeStream {
	if (!_opened) {
#warning this should schedule the inner write stream in the same manner as the parent transport layer
		[[self readStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
		[[self readStream] open];
		
		_opened = YES;
	}
	
	do {
		if ([self currentWrite] == nil) {
			size_t bufferSize = (32 * 1024);
			if (_numberOfBytesToRead >= 0) {
				bufferSize = MIN(_numberOfBytesToRead, bufferSize);
				_numberOfBytesToRead -= bufferSize;
				
				if (bufferSize == 0) break;
			}
			
			AFPacketRead *readPacket = [[[AFPacketRead alloc] initWithContext:NULL timeout:-1 terminator:[NSNumber numberWithInteger:bufferSize]] autorelease];
			[self setCurrentRead:readPacket];
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:readPacket];
		}
		
		if ([self currentWrite] == nil) return;
		
		BOOL writeSucceeded = [[self currentWrite] performWrite:writeStream error:errorRef];
		if (!writeSucceeded) return;
	} while ([self currentWrite] == nil);
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	AFPacketRead *readPacket = [notification object];
	
	NSData *readBuffer = [readPacket buffer];
	AFPacketWrite *writePacket = [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:readBuffer] autorelease];
#warning do something with the packet
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:readPacket];
	[self setCurrentRead:nil];
}

- (void)_writePacketDidComplete:(NSNotification *)notification {
	AFPacketWrite *packet = [notification object];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:packet];
	[self setCurrentWrite:nil];
	
	NSError *writeError = [[notification userInfo] objectForKey:AFPacketErrorKey];
	if (writeError != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	if (!(_numberOfBytesToRead < 0 && CFReadStreamGetStatus(_readStream) == kCFStreamStatusAtEnd) && _numberOfBytesToRead != 0) return;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
}

@end
