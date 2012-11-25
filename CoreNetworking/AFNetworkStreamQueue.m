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
@synthesize queueSuspendCount=_packetQueueSuspendCount, packetQueue=_packetQueue;

- (id)initWithStream:(NSStream *)stream {
	NSParameterAssert([_stream streamStatus] == NSStreamStatusNotOpen);
	
	self = [self init];
	if (self == nil) return nil;
	
	_stream = [stream retain];
	[_stream setDelegate:self];
	
#if !defined(OBJC_NO_GC)
	/*
		Note
		
		the stream maintains a non zeroing weak reference to this object, there is no safe time (other than structured teardown) to finalize with this reference in place
	 */
	if ([NSGarbageCollector defaultCollector] != nil) {
		static NSString *_AFNetworkStreamDelegateStrongReferenceAssociationContext;
		objc_setAssociatedObject(_stream, &_AFNetworkStreamDelegateStrongReferenceAssociationContext, self, OBJC_ASSOCIATION_RETAIN);
	}
#endif /* !defined(OBJC_NO_GC) */
	
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
	
	if (_sources._runLoopSource != NULL) {
		CFRelease(_sources._runLoopSource);
		_sources._runLoopSource = NULL;
	}
	
#if defined(DISPATCH_API_VERSION)
	if (_sources._dispatchSource != NULL) {
		dispatch_source_cancel(_sources._dispatchSource);
		dispatch_release(_sources._dispatchSource);
		_sources._dispatchSource = NULL;
	}
#endif
	
	[self _stopCurrentPacket];
	[_packetQueue release];
	
	[super dealloc];
}

- (void)finalize {
#if defined(DISPATCH_API_VERSION)
	if (_sources._dispatchSource != NULL) {
		dispatch_source_cancel(_sources._dispatchSource);
		dispatch_release(_sources._dispatchSource);
		_sources._dispatchSource = NULL;
	}
#endif
	
	[super finalize];
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

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(_sources._dispatchSource == NULL);
	
	if (_sources._runLoopSource == NULL) {
		/*
			Note:
			
			this acts a placeholder to ensure a caller doesn't schedule the receiver in a dispatch_packetQueue
		 */
		_sources._runLoopSource = (CFTypeRef)CFMakeCollectable(CFRetain([[[NSObject alloc] init] autorelease]));
	}
	
	[self.stream scheduleInRunLoop:runLoop forMode:mode];
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(_sources._runLoopSource != NULL);
	
	[self.stream removeFromRunLoop:runLoop forMode:mode];
}

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	NSParameterAssert(_sources._runLoopSource == NULL);
	
#if 0
	if (queue != NULL) {
		if (_sources._dispatchSource == NULL) {
			typedef id (*CopyStreamProperty)(CFTypeRef, CFStringRef);
			
			typedef CFSocketNativeHandle (^GetNativeStreamHandle)(CopyStreamProperty copyProperty, CFTypeRef stream);
			GetNativeStreamHandle getNativeHandle = ^ CFSocketNativeHandle (CopyStreamProperty copyProperty, CFTypeRef stream) {
				CFSocketNativeHandle handle = 0;
				NSData *handleData = [(id)stream propertyForKey:(id)kCFStreamPropertySocketNativeHandle];
				
				NSParameterAssert(handleData != nil && [handleData length] > 0 && sizeof(CFSocketNativeHandle) <= [handleData length]);
				[handleData getBytes:&handle length:[handleData length]];
				
				return handle;
			};
			
			CopyStreamProperty getter = NULL;
			
			dispatch_source_type_t sourceType = 0;
			NSStreamEvent eventType = NSStreamEventNone;
			
			if ([self.stream isKindOfClass:[NSOutputStream class]]) {
				getter = (CopyStreamProperty)CFWriteStreamCopyProperty;
				
				sourceType = DISPATCH_SOURCE_TYPE_WRITE;
				eventType = NSStreamEventHasSpaceAvailable;
			}
			else if ([self.stream isKindOfClass:[NSInputStream class]]) {
				getter = (CopyStreamProperty)CFReadStreamCopyProperty;
				
				sourceType = DISPATCH_SOURCE_TYPE_READ;
				eventType = NSStreamEventHasBytesAvailable;
			}
			else {
				@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%s, cannot schedule stream of class %@", __PRETTY_FUNCTION__, [self.stream class]] userInfo:nil];
				return;
			}
			
			dispatch_source_t newSource = dispatch_source_create(sourceType, getNativeHandle(getter, self.stream), 0, queue);
			dispatch_source_set_event_handler(newSource, ^ {
				if ([self.stream streamStatus] == NSStreamStatusNotOpen) {
					return;
				}
				
				if ([self.stream streamStatus] == NSStreamStatusOpening) {
					return;
				}
				
				if ([self.stream streamStatus] == NSStreamStatusOpen && ![self isOpen]) {
					[self stream:self.stream handleEvent:NSStreamEventOpenCompleted];
					NSParameterAssert([self isOpen]);
				}
				
				[self stream:self.stream handleEvent:eventType];
			});
			dispatch_source_set_cancel_handler(newSource, ^ {
				[self close];
			});
			
			_sources._dispatchSource = newSource;
			return;
		}
		
		dispatch_set_target_queue(_sources._dispatchSource, queue);
		return;
	}
	
	if (_sources._dispatchSource != NULL) {
		dispatch_source_cancel(_sources._dispatchSource);
		dispatch_release(_sources._dispatchSource);
		_sources._dispatchSource = NULL;
	}
#else
	@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ doesn't support scheduling in a queue currently", NSStringFromClass([self class])] userInfo:nil];
#endif
}

#endif /* defined(DISPATCH_API_VERSION) */

- (void)_resumeSources {
	if (_sources._runLoopSource != NULL) {
		//nop
	}
	
#if defined(DISPATCH_API_VERSION)
	if (_sources._dispatchSource != NULL) {
		dispatch_resume(_sources._dispatchSource);
	}
#endif /* defined(DISPATCH_API_VERSION) */
}

- (void)open {
	NSParameterAssert(_sources._runLoopSource != NULL || _sources._dispatchSource != NULL);
	NSParameterAssert(_delegate != nil);
	
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
	if ((self.streamFlags & _AFNetworkStreamFlagsTryDequeue) == _AFNetworkStreamFlagsTryDequeue && (newStreamFlags & _AFNetworkStreamFlagsTryDequeue) == 0) {
#if defined(DISPATCH_API_VERSION)
		if (_sources._dispatchSource != NULL) {
			dispatch_resume(_sources._dispatchSource);
		}
#endif /* defined(DISPATCH_API_VERSION) */
	}
	else if ((self.streamFlags & _AFNetworkStreamFlagsTryDequeue) == 0 && (newStreamFlags & _AFNetworkStreamFlagsTryDequeue) == _AFNetworkStreamFlagsTryDequeue) {
#if defined(DISPATCH_API_VERSION)
		if (_sources._dispatchSource != NULL) {
			dispatch_suspend(_sources._dispatchSource);
		}
#endif /* defined(DISPATCH_API_VERSION) */
	}
	
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
