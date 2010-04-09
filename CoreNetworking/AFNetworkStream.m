//
//  AFNetworkStream.m
//  Amber
//
//  Created by Keith Duncan on 02/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFNetworkStream.h"

#import <objc/message.h>

#import "AFPriorityProxy.h"
#import "AFNetworkTransport.h"
#import "AFPacketQueue.h"
#import "AFPacket.h"
#import "AFNetworkConstants.h"

@interface AFNetworkStream () <NSStreamDelegate>
@property (readonly) NSStream *stream;
@property (readonly) AFPacketQueue *queue;
@end

@interface AFNetworkStream (_Queue)
- (void)_tryDequeuePackets;
- (void)_startPacket:(AFPacket *)packet;
- (void)_shouldTryDequeuePacket;
- (void)_packetDidTimeout:(NSNotification *)notification;
- (void)_packetDidComplete:(NSNotification *)notification;
@end

@interface AFNetworkStream (_Subclasses)

@end

@implementation AFNetworkStream

@synthesize delegate=_delegate;
@synthesize stream=_stream, queue=_queue;

- (id)initWithStream:(NSStream *)stream {
	NSParameterAssert([stream streamStatus] == NSStreamStatusNotOpen);
	
	self = [self init];
	if (self == nil) return nil;
	
	_stream = [stream retain];
	[_stream setDelegate:self];
	
	return self;
}

- (void)dealloc {
	[_stream release];
	
	if (_source != NULL) {
		dispatch_source_cancel(_source);
		dispatch_release(_source);
		_source = NULL;
	}
	
	[super dealloc];
}

- (void)finalize {
	if (_source != NULL) {
		dispatch_source_cancel(_source);
		dispatch_release(_source);
		_source = NULL;
	}
	
	[super finalize];
}

- (AFPriorityProxy *)delegateProxy:(AFPriorityProxy *)proxy {
	if (_delegate == nil) return proxy;
	
	if (proxy == nil) proxy = [[[AFPriorityProxy alloc] init] autorelease];
	
	if ([_delegate respondsToSelector:@selector(delegateProxy:)]) proxy = [(id)_delegate delegateProxy:proxy];
	[proxy insertTarget:_delegate];
	
	return proxy;
}

- (id <AFNetworkStreamDelegate>)delegate {
	return (id)[self delegateProxy:nil];
}

- (NSString *)description {
	NSMutableString *description = [[super description] mutableCopy];
	
	static const char *StreamStatusStrings[] = { "not open", "opening", "open", "reading", "writing", "at end", "closed", "has error" };
	[description appendFormat:@"\tStream: %p %s, ", self.stream, (self.stream != nil ? StreamStatusStrings[[self.stream streamStatus]] : ""), nil];
	[description appendFormat:@"Current Read: %@", [self.queue currentPacket], nil];
	[description appendString:@"\n"];
	
	return description;
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	[self.stream scheduleInRunLoop:runLoop forMode:mode];
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	[self.stream removeFromRunLoop:runLoop forMode:mode];
}

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	typedef id (*CopyStreamProperty)(CFTypeRef, CFStringRef);
	typedef CFSocketNativeHandle (^GetNativeSteamHandle)(CopyStreamProperty copyProperty, CFTypeRef stream);
	GetNativeSteamHandle getNativeHandle = ^ CFSocketNativeHandle (CopyStreamProperty copyProperty, CFTypeRef stream) {
		CFSocketNativeHandle handle = 0;
		NSData *handleData = [NSMakeCollectable(copyProperty(stream, kCFStreamPropertySocketNativeHandle)) autorelease];
		NSParameterAssert(handleData != nil && [handleData length] > 0 && sizeof(CFSocketNativeHandle) <= [handleData length]);
		[handleData getBytes:&handle length:[handleData length]];
		
		return handle;
	};
	
	if (_source != NULL) {
		dispatch_source_cancel(_source);
		dispatch_release(_source);
		_source = NULL;
	}
	
	if (queue == NULL) return;
	
	CopyStreamProperty getter = NULL;
	if ([self.stream isKindOfClass:[NSOutputStream class]]) {
		getter = (CopyStreamProperty)CFWriteStreamCopyProperty;
	} else if ([self.stream isKindOfClass:[NSInputStream class]]) {
		getter = (CopyStreamProperty)CFReadStreamCopyProperty;
	} else {
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot schedule stream of class %@", __PRETTY_FUNCTION__, [self.stream class]];
		return;
	}
	
	dispatch_source_t newSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, getNativeHandle(getter, self.stream), 0, queue);
	
	dispatch_source_set_event_handler(newSource, ^ {
		[self stream:self.stream handleEvent:NSStreamEventHasSpaceAvailable];
	});
	
	dispatch_source_set_cancel_handler(newSource, ^ {
		[self close];
	});
	
	dispatch_resume(newSource);
	_source = newSource;
}

#endif

- (void)open {
	[self.stream open];
}

- (void)close {
	[self.queue emptyQueue];
	[self.stream close];
}

- (id)streamPropertyForKey:(NSString *)key {
	return [self.stream propertyForKey:key];
}

- (BOOL)setStreamProperty:(id)property forKey:(NSString *)key {
	return [self.stream setProperty:property forKey:key];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
	if (event == NSStreamEventHasBytesAvailable || event == NSStreamEventHasSpaceAvailable) {
		[self _tryDequeuePackets];
		return;
	}
	
	if (event == NSStreamEventErrorOccurred) {
		[[self delegate] networkStream:self didReceiveError:[stream streamError]];
		return;
	}
	
	[[self delegate] networkStream:self didReceiveEvent:event];
}

@end

@implementation AFNetworkStream (_Queue)

- (void)_tryDequeuePackets {
	if ([self.delegate respondsToSelector:@selector(networkStreamCanDequeuePacket:)])
		if (![self.delegate networkStreamCanDequeuePacket:self]) return;
	
	if (_dequeuing) return;
	_dequeuing = YES;
	
	do {
		if ([self.queue tryDequeue]) {
			[self _startPacket:self.queue.currentPacket];
		} else break;
		
		[self _shouldTryDequeuePacket];
	} while (self.queue.currentPacket == nil);
	
	_dequeuing = NO;
}

- (void)_startPacket:(AFPacket *)packet {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_packetDidComplete:) name:AFPacketDidCompleteNotificationName object:packet];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_packetDidTimeout:) name:AFPacketDidTimeoutNotificationName object:packet];
	[packet startTimeout];
}

- (void)_shouldTryDequeuePacket {
	AFPacket *packet = [self.queue currentPacket];
	BOOL performSucceeded = ((BOOL (*)(id, SEL, id))objc_msgSend)(packet, _performSelector, self.stream);
	if (!performSucceeded) return;
	
	if ([self.delegate respondsToSelector:_callbackSelectors[0]]) {
		NSUInteger bytesWritten = 0, totalBytes = 0;
		[packet currentProgressWithBytesDone:&bytesWritten bytesTotal:&totalBytes];
		
		((void (*)(id, SEL, id, id, NSUInteger, NSUInteger))objc_msgSend)(self.delegate, _callbackSelectors[0], self, packet, bytesWritten, totalBytes);
	}
}

- (void)_packetDidTimeout:(NSNotification *)notification {
	AFPacket *packet = [notification object];
	
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							   NSLocalizedStringWithDefaultValue(@"AFNetworkStream Packet Did Timeout Error", @"AFNetworkStream", [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"Packet timeout.", nil), NSLocalizedDescriptionKey,
							   nil];
	NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkTransportTimeoutError userInfo:errorInfo];
	
	[self.delegate networkStream:self didReceiveError:error];
	[self _packetDidComplete:notification];
}

- (void)_packetDidComplete:(NSNotification *)notification {
	AFPacket *packet = [notification object];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:packet];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidTimeoutNotificationName object:packet];
	[packet stopTimeout];
	
	NSError *packetError = [[notification userInfo] objectForKey:AFPacketErrorKey];
	if (packetError != nil) [[self delegate] networkStream:self didReceiveError:packetError];
	
	((void (*)(id, SEL, id, id))objc_msgSend)(self.delegate, _callbackSelectors[1], self, packet);
	
	[self.queue dequeued];
	
	if ([self.delegate respondsToSelector:@selector(networkStreamDidDequeuePacket:)])
		[self.delegate networkStreamDidDequeuePacket:self];
	
	[self _tryDequeuePackets];
}

@end

#pragma mark -

@implementation AFNetworkWriteStream

@dynamic delegate;

- (id)initWithStream:(NSStream *)stream {
	self = [super initWithStream:stream];
	if (self == nil) return nil;
	
	_callbackSelectors[0] = @selector(networkStream:didWrite:partialDataOfLength:totalBytes:);
	_callbackSelectors[1] = @selector(networkStream:didWrite:);
	
	_performSelector = @selector(performWrite:);
	
	return self;
}

- (void)enqueueWrite:(id <AFPacketWriting>)packet {
	[self.queue enqueuePacket:packet];
}

- (NSUInteger)countOfEnqueuedWrites {
	return [self.queue count];
}

@end

@implementation AFNetworkReadStream

@dynamic delegate;

- (id)initWithStream:(NSStream *)stream {
	self = [super initWithStream:stream];
	if (self == nil) return nil;
	
	_callbackSelectors[0] = @selector(networkStream:didRead:partialDataOfLength:totalBytes:);
	_callbackSelectors[1] = @selector(networkStream:didRead:);
	
	_performSelector = @selector(performRead:);
	
	return self;
}

- (void)enqueueRead:(id <AFPacketReading>)packet {
	[self.queue enqueuePacket:packet];
}

- (NSUInteger)countOfEnqueuedReads {
	return [self.queue count];
}

@end
