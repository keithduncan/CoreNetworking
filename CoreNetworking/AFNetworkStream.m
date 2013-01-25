//
//  AFNetworkStream.m
//  Go Server
//
//  Created by Keith Duncan on 17/12/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFNetworkStream.h"

#import "CoreNetworking/CoreNetworking.h"

@interface _AFNetworkPrivateStream : NSStream
@property (assign, nonatomic) int fileDescriptor;

@property (assign, nonatomic) id <NSStreamDelegate> delegate;

@property (assign, nonatomic) NSStreamStatus streamStatus;
@property (retain, nonatomic) NSError *streamError;

@property (retain, nonatomic) AFNetworkSchedule *schedule;
@end

@implementation _AFNetworkPrivateStream {
	struct {
		struct {
			CFFileDescriptorRef _fileDescriptor;
			CFRunLoopSourceRef _source;
		} _runLoop;
		struct {
			dispatch_source_t _source;
		} _dispatch;
	} _sources;
}

static void _AFNetworkStreamSetNonBlocking(int fileDescriptor) {
	int originalFlags = fcntl(fileDescriptor, F_GETFL);
	if ((originalFlags & O_NONBLOCK) == 0) {
		fcntl(fileDescriptor, F_SETFL, (originalFlags | O_NONBLOCK));
	}
}

static void _AFNetworkStreamNotify(_AFNetworkPrivateStream *stream, NSStreamEvent event) {
	if (![stream.delegate respondsToSelector:@selector(stream:handleEvent:)]) {
		return;
	}
	[stream.delegate stream:stream handleEvent:event];
}

static void _AFNetworkStreamSetStreamStatusAndNotify(_AFNetworkPrivateStream *stream, NSStreamStatus status) {
	stream.streamStatus = status;
	
	struct StatusToEvent {
		NSStreamStatus status;
		NSStreamEvent event;
	} statusToEventMap[] = {
		{ .status = NSStreamStatusOpen, .event = NSStreamEventOpenCompleted },
		{ .status = NSStreamStatusAtEnd, .event = NSStreamEventEndEncountered },
		{ .status = NSStreamStatusError, .event = NSStreamEventErrorOccurred },
	};
	for (NSUInteger idx = 0; idx < sizeof(statusToEventMap)/sizeof(*statusToEventMap); idx++) {
		if (statusToEventMap[idx].status != status) {
			continue;
		}
		
		_AFNetworkStreamNotify(stream, statusToEventMap[idx].event);
		break;
	}
}

static void _AFNetworkStreamOpen(id stream) {
	_AFNetworkStreamSetStreamStatusAndNotify(stream, NSStreamStatusOpen);
}

static void _AFNetworkStreamClose(_AFNetworkPrivateStream *stream) {
	CFFileDescriptorRef *fileDescriptorRef = &stream->_sources._runLoop._fileDescriptor;
	dispatch_source_t *sourceRef = &stream->_sources._dispatch._source;
	
	if (*fileDescriptorRef != NULL) {
		CFFileDescriptorInvalidate(*fileDescriptorRef);
	}
	else if (*sourceRef != NULL) {
		dispatch_source_cancel(*sourceRef);
	}
	else {
		close(stream.fileDescriptor);
		stream.fileDescriptor = -1;
	}
	
	_AFNetworkStreamSetStreamStatusAndNotify(stream, NSStreamStatusClosed);
}

@synthesize fileDescriptor=_fileDescriptor;
@synthesize delegate=_delegate;

@synthesize streamStatus=_streamStatus, streamError=_streamError;

- (id)initWithFileDescriptor:(int)fileDescriptor {
	self = [self init];
	if (self == nil) return nil;
	
	_fileDescriptor = fileDescriptor;
	_AFNetworkStreamSetNonBlocking(_fileDescriptor);
	
	return self;
}

- (void)dealloc {
	[_streamError release];
	[_schedule release];
	
	[self close];
	
	CFFileDescriptorRef *fileDescriptorRef = &_sources._runLoop._fileDescriptor;
	dispatch_source_t *sourceRef = &_sources._dispatch._source;
	
	if (*fileDescriptorRef != NULL) {
		CFRelease(*fileDescriptorRef);
		CFRelease(_sources._runLoop._source);
	}
	else if (*sourceRef != NULL) {
		dispatch_release(*sourceRef);
	}
	else if (_fileDescriptor >= 0) {
		close(_fileDescriptor);
	}
	
	[super dealloc];
}

- (void)setDelegate:(id <NSStreamDelegate>)delegate {
	_delegate = (delegate ? : (id)self);
}

- (id)propertyForKey:(NSString *)key {
	return nil;
}

- (BOOL)setProperty:(id)property forKey:(NSString *)key {
	return NO;
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInRunLoop:runLoop forMode:mode];
	self.schedule = newSchedule;
}

- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"cannot unschedule stream" userInfo:nil];
}

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInQueue:queue];
	self.schedule = newSchedule;
}

static void _AFNetworkStreamFileDescriptorEnableCallbacks(CFFileDescriptorRef f) {
	CFFileDescriptorEnableCallBacks(f, kCFFileDescriptorReadCallBack | kCFFileDescriptorWriteCallBack);
}

static void _AFNetworkStreamFileDescriptorCallBack(CFFileDescriptorRef f, CFOptionFlags callBackTypes, void *info) {
	_AFNetworkPrivateStream *self = info;
	
	if ((callBackTypes & kCFFileDescriptorReadCallBack) == kCFFileDescriptorReadCallBack) {
		_AFNetworkStreamNotify(self, NSStreamEventHasBytesAvailable);
	}
	else if ((callBackTypes & kCFFileDescriptorWriteCallBack) == kCFFileDescriptorWriteCallBack) {
		_AFNetworkStreamNotify(self, NSStreamEventHasSpaceAvailable);
	}
	
	_AFNetworkStreamFileDescriptorEnableCallbacks(f);
}

- (void)open {
	AFNetworkSchedule *schedule = self.schedule;
	NSParameterAssert(schedule != nil);
	
	if (schedule->_runLoop != nil) {
		NSRunLoop *runLoop = schedule->_runLoop;
		
		CFFileDescriptorContext context = {
			.info = self,
		};
		CFFileDescriptorRef newFileDescriptor = CFFileDescriptorCreate(kCFAllocatorDefault, self.fileDescriptor, true, _AFNetworkStreamFileDescriptorCallBack, &context);
		_sources._runLoop._fileDescriptor = newFileDescriptor;
		
		CFRunLoopSourceRef newRunLoopSource = CFFileDescriptorCreateRunLoopSource(kCFAllocatorDefault, newFileDescriptor, 0);
		_sources._runLoop._source = newRunLoopSource;
		
		CFRunLoopAddSource([runLoop getCFRunLoop], newRunLoopSource, (CFStringRef)schedule->_runLoopMode);
		
		_AFNetworkStreamFileDescriptorEnableCallbacks(newFileDescriptor);
	}
	else {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"unknown schedule environment" userInfo:nil];
	}
	
	_AFNetworkStreamOpen(self);
}

- (void)close {
	_AFNetworkStreamClose(self);
}

#pragma mark - Write Stream

- (NSInteger)write:(uint8_t const *)buffer maxLength:(NSUInteger)maxLength {
	ssize_t size = write(self.fileDescriptor, buffer, maxLength);
	if (size == -1) {
		int error = errno;
		if (error == EWOULDBLOCK) {
			return 0;
		}
		
		self.streamError = [NSError errorWithDomain:NSPOSIXErrorDomain code:error userInfo:nil];
		return -1;
	}
	
	return size;
}

- (BOOL)hasSpaceAvailable {
	/*
		Note
		
		the file descriptors is in non blocking mode -write: will return whether there is space or not
	 */
	return YES;
}

#pragma mark - Read Stream

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
	ssize_t size = read(self.fileDescriptor, buffer, len);
	if (size == -1) {
		int error = errno;
		if (error == EWOULDBLOCK) {
			return 0;
		}
		
		self.streamError = [NSError errorWithDomain:NSPOSIXErrorDomain code:error userInfo:nil];
		return -1;
	}
	
	return size;
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
	return NO;
}

- (BOOL)hasBytesAvailable {
	return YES;
}

@end

#pragma mark -

@implementation AFNetworkOutputStream

- (id)initWithFileDescriptor:(int)fileDescriptor
{
	[self release];
	
	return (AFNetworkOutputStream *)[[_AFNetworkPrivateStream alloc] initWithFileDescriptor:fileDescriptor];
}

@end

@implementation AFNetworkInputStream

- (id)initWithFileDescriptor:(int)fileDescriptor
{
	[self release];
	
	return (AFNetworkInputStream *)[[_AFNetworkPrivateStream alloc] initWithFileDescriptor:fileDescriptor];
}

@end
