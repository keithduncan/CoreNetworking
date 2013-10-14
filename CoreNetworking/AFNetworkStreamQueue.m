//
//  AFNetworkStream.m
//  Amber
//
//  Created by Keith Duncan on 02/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFNetworkStreamQueue.h"

#import <objc/message.h>
#import <objc/objc-auto.h>
#import <netdb.h>

#import "AFNetworkTransport.h"
#import "AFNetworkPacketQueue.h"
#import "AFNetworkSchedule.h"

#import "AFNetworkDelegateProxy.h"

#import "AFNetworkPacket+AFNetworkPrivate.h"

#import "AFNetwork-Constants.h"
#import "AFNetwork-Macros.h"

typedef AFNETWORK_OPTIONS(NSUInteger, _AFNetworkStreamFlags) {
	_AFNetworkStreamFlagsDidOpen = 1UL << 0,
	_AFNetworkStreamFlagsTryDequeue = 1UL << 1,
};

@interface AFNetworkStreamQueue () <NSStreamDelegate>
@property (assign, nonatomic) NSUInteger streamFlags;

@property (readonly, nonatomic) NSStream *stream;

@property (retain, nonatomic) AFNetworkSchedule *schedule;
- (void)_resumeSources;

@property (assign, nonatomic) NSUInteger queueSuspendCount;
@property (readonly, nonatomic) AFNetworkPacketQueue *packetQueue;
@end

@interface AFNetworkStreamQueue (AFNetworkStreamPrivate)
- (void)_updateStreamFlags:(_AFNetworkStreamFlags)newStreamFlags;

- (void)_tryClearDequeuePacketsIfScheduled;
- (void)_tryClearDequeuePackets;

- (BOOL)_canDequeuePackets;
- (void)_tryDequeuePackets;
- (void)_startPacket:(AFNetworkPacket *)packet;
- (void)_stopCurrentPacket;
- (void)_stopPacket:(AFNetworkPacket *)packet;
- (void)_performPacket;

- (void)_packetDidComplete:(NSNotification *)notification;

- (void)_forwardError:(NSError *)error;
@end

@interface AFNetworkStreamQueue (_Subclasses)

@end

@implementation AFNetworkStreamQueue

@synthesize delegate=_delegate;
@synthesize stream=_stream;
@synthesize streamFlags=_streamFlags;
@synthesize schedule=_schedule;
@synthesize queueSuspendCount=_queueSuspendCount, packetQueue=_packetQueue;

- (id)initWithStream:(NSStream *)stream {
	NSParameterAssert([_stream streamStatus] == NSStreamStatusNotOpen);
	
	self = [self init];
	if (self == nil) return nil;
	
	_stream = [stream retain];
	[_stream setDelegate:self];
	
	if ([_stream isKindOfClass:[NSOutputStream class]]) {
		_performSelector = @selector(performWrite:);
	}
	else if ([_stream isKindOfClass:[NSInputStream class]]) {
		_performSelector = @selector(performRead:);
	}
	else {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s, stream not an NSOutputStream or an NSInputStream (%@)", __PRETTY_FUNCTION__, stream] userInfo:nil];
		return nil;
	}
	
	_packetQueue = [[AFNetworkPacketQueue alloc] init];
	
	return self;
}

- (void)dealloc {
	[_stream setDelegate:nil];
	[_stream release];
	
	[_schedule release];
	
	[self _stopCurrentPacket];
	[_packetQueue release];
	
	[super dealloc];
}

- (AFNetworkDelegateProxy *)delegateProxy:(AFNetworkDelegateProxy *)proxy {	
	if (_delegate == nil) {
		return proxy;
	}
	
	if (proxy == nil) {
		proxy = [[[AFNetworkDelegateProxy alloc] init] autorelease];
	}
	
	if ([_delegate respondsToSelector:@selector(delegateProxy:)]) {
		proxy = [(id)_delegate delegateProxy:proxy];
	}
	
	[proxy insertTarget:_delegate];
	
	return proxy;
}

- (id)delegate {
	return [self delegateProxy:nil];
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	
	[description appendFormat:@" "];
	[description appendFormat:@"%@, ", self.stream];
	[description appendFormat:@"Open: %@, ", ((self.streamFlags & _AFNetworkStreamFlagsDidOpen) == _AFNetworkStreamFlagsDidOpen) ? @"YES" : @"NO"];
	[description appendFormat:@"Try Dequeue: %@, ", ((self.streamFlags & _AFNetworkStreamFlagsTryDequeue) == _AFNetworkStreamFlagsTryDequeue) ? @"YES" : @"NO"];
	[description appendFormat:@"Queued Packets: %lu, ", (NSUInteger)[self.packetQueue count]];
	[description appendFormat:@"Current Packet: %@", [self.packetQueue currentPacket]];
	[description appendString:@"\n"];
	
	return description;
}

- (BOOL)_isScheduled {
	return (self.schedule != nil);
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(![self _isScheduled]);
	
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInRunLoop:runLoop forMode:mode];
	self.schedule = newSchedule;
}

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	NSParameterAssert(![self _isScheduled]);
	
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInQueue:queue];
	self.schedule = newSchedule;
}

- (void)_resumeSources {
	AFNetworkSchedule *schedule = self.schedule;
	
	NSStream *stream = self.stream;
	
	if (schedule->_runLoop != nil) {
		NSRunLoop *runLoop = schedule->_runLoop;
		
		[stream scheduleInRunLoop:runLoop forMode:schedule->_runLoopMode];
	}
	else if (schedule->_dispatchQueue != NULL) {
		if ([stream isKindOfClass:[NSOutputStream class]]) {
			CFReadStreamSetDispatchQueue((CFReadStreamRef)stream, schedule->_dispatchQueue);
		}
		else if ([stream isKindOfClass:[NSInputStream class]]) {
			CFWriteStreamSetDispatchQueue((CFWriteStreamRef)stream, schedule->_dispatchQueue);
		}
	}
	else {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"unsupported schedule environment, cannot resume stream" userInfo:nil];
	}
}

- (void)open {
	NSParameterAssert([self _isScheduled]);
	NSParameterAssert(self.delegate != nil);
	
	if ([self isOpen]) {
		return;
	}
	
	[self _resumeSources];
	
	[self.stream open];
}

- (BOOL)isOpen {
	return ((self.streamFlags & _AFNetworkStreamFlagsDidOpen) == _AFNetworkStreamFlagsDidOpen);
}

- (void)close {
	if ([self isClosed]) {
		return;
	}
	
	[self _stopCurrentPacket];
	[self.packetQueue emptyQueue];
	
	[self.stream close];
}

- (BOOL)isClosed {
	return ([self.stream streamStatus] == NSStreamStatusClosed);
}

- (id)streamPropertyForKey:(NSString *)key {
	return [self.stream propertyForKey:key];
}

- (BOOL)setStreamProperty:(id)property forKey:(NSString *)key {
	return [self.stream setProperty:property forKey:key];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
	/*
		Note
		
		the open and has* events MUST be forwarded to the delegate before we attempt to handle them, as we ask the delegate if it's open before dequeuing
	 */
	
	if (event == NSStreamEventOpenCompleted) {
		[self.delegate networkStream:self didReceiveEvent:event];
		
		[self _updateStreamFlags:(self.streamFlags | _AFNetworkStreamFlagsDidOpen)];
		return;
	}
	
	if (event == NSStreamEventHasBytesAvailable || event == NSStreamEventHasSpaceAvailable) {
		[self.delegate networkStream:self didReceiveEvent:event];
		
		[self _updateStreamFlags:(self.streamFlags | _AFNetworkStreamFlagsTryDequeue)];
		
		[self _tryClearDequeuePackets];
		return;
	}
	
	if (event == NSStreamEventErrorOccurred) {
		[self _forwardError:[stream streamError]];
		return;
	}
	
	if (event == NSStreamEventEndEncountered) {
		[self.delegate networkStream:self didReceiveEvent:event];
		return;
	}
	
	@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s, unknown stream event %lu", __PRETTY_FUNCTION__, event] userInfo:nil];
}

- (void)enqueuePacket:(AFNetworkPacket *)packet {
	[self.packetQueue enqueuePacket:packet];
	
	[self _tryClearDequeuePacketsIfScheduled];
}

- (NSUInteger)countOfEnqueuedPackets {
	return [self.packetQueue count];
}

- (void)suspendPacketQueue {
	[self setQueueSuspendCount:([self queueSuspendCount] + 1)];
}

- (void)resumePacketQueue {
	NSParameterAssert([self queueSuspendCount] > 0);
	[self setQueueSuspendCount:([self queueSuspendCount] - 1)];
	
	if ([self queueSuspendCount] != 0) {
		return;
	}
	
	[self _tryClearDequeuePacketsIfScheduled];
}

@end

@implementation AFNetworkStreamQueue (AFNetworkStreamPrivate)

- (void)_updateStreamFlags:(_AFNetworkStreamFlags)newStreamFlags {
	self.streamFlags = newStreamFlags;
}

- (void)_tryClearDequeuePacketsIfScheduled {
	if ((self.streamFlags & _AFNetworkStreamFlagsTryDequeue) != _AFNetworkStreamFlagsTryDequeue) {
		return;
	}
	
	[self _tryClearDequeuePackets];
}

- (void)_tryClearDequeuePackets {
	if ([self.packetQueue count] == 0) {
		return;
	}
	
	[self _tryDequeuePackets];
	
	if ([self.packetQueue count] != 0) {
		return;
	}
	
	[self _updateStreamFlags:(self.streamFlags & ~_AFNetworkStreamFlagsTryDequeue)];
}

- (BOOL)_canDequeuePackets {
	if (![self isOpen]) {
		return NO;
	}
	
	if ([self queueSuspendCount] > 0) {
		return NO;
	}
	
	return YES;
}

- (void)_tryDequeuePackets {
	if (_dequeuing) {
		return;
	}
	_dequeuing = YES;
	
	do {
		if (![self _canDequeuePackets]) {
			break;
		}
		
		if (self.packetQueue.currentPacket == nil) {
			if (![self.packetQueue tryDequeue]) {
				break;
			}
			[self _startPacket:self.packetQueue.currentPacket];
		}
		
		[self _performPacket];
	} while (self.packetQueue.currentPacket == nil);
	
	_dequeuing = NO;
}

- (void)_startPacket:(AFNetworkPacket *)packet {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_packetDidComplete:) name:AFNetworkPacketDidCompleteNotificationName object:packet];
}

- (void)_stopCurrentPacket {
	AFNetworkPacket *currentPacket = self.packetQueue.currentPacket;
	if (currentPacket == nil) {
		return;
	}
	
	[self _stopPacket:currentPacket];
}

- (void)_stopPacket:(AFNetworkPacket *)packet {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkPacketDidCompleteNotificationName object:packet];
	
	[packet _stopIdleTimeoutTimer];
}

- (void)_performPacket {
	AFNetworkPacket *packet = [[self.packetQueue.currentPacket retain] autorelease];
	NSInteger bytesTransferred = ((NSInteger (*)(id, SEL, id))objc_msgSend)(packet, _performSelector, self.stream);
	if (bytesTransferred == -1) {
		return;
	}
	
	if ([self.delegate respondsToSelector:@selector(networkStream:didTransfer:bytesTransferred:totalBytesTransferred:totalBytesExpectedToTransfer:)]) {
		NSInteger totalBytesTransferred = 0, totalBytesExpectedToTransfer = 0;
		[packet currentProgressWithBytesDone:&totalBytesTransferred bytesTotal:&totalBytesExpectedToTransfer];
		
		[self.delegate networkStream:self didTransfer:packet bytesTransferred:bytesTransferred totalBytesTransferred:totalBytesTransferred totalBytesExpectedToTransfer:totalBytesExpectedToTransfer];
	}
	
	/*
		Note
		
		if the packet didn't complete, start the idle timer
	 */
	if (packet == self.packetQueue.currentPacket) {
		[packet _resetIdleTimeoutTimer];
	}
}

- (void)_packetDidComplete:(NSNotification *)notification {
	AFNetworkPacket *packet = [notification object];
	
	[self _stopPacket:packet];
	[self.packetQueue dequeued];
	
	NSError *packetError = [[notification userInfo] objectForKey:AFNetworkPacketErrorKey];
	if (packetError != nil) {
		[self _forwardError:packetError];
	}
	
	if ([self.delegate respondsToSelector:@selector(networkStream:didDequeuePacket:)]) {
		[self.delegate networkStream:self didDequeuePacket:packet];
	}
	
	[self _tryClearDequeuePacketsIfScheduled];
}

- (void)_forwardError:(NSError *)error {
	[self.delegate networkStream:self didReceiveError:error];
}

@end
