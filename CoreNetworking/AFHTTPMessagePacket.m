//
//  AFHTTPMessagePacket.m
//  Amber
//
//  Created by Keith Duncan on 15/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPMessagePacket.h"

#import "AFHTTPHeadersPacket.h"
#import "AFHTTPBodyPacket.h"
#import "AFHTTPMessage.h"
#import "AFNetworkConstants.h"

#import "AFNetworkMacros.h"

AFNETWORK_NSSTRING_CONTEXT(_AFHTTPMessagePacketHeadersContext);
AFNETWORK_NSSTRING_CONTEXT(_AFHTTPMessagePacketBodyContext);

@interface AFHTTPMessagePacket ()
@property (readonly) CFHTTPMessageRef message;

@property (readwrite, retain) NSOutputStream *bodyStream;

@property (retain) AFNetworkPacket <AFNetworkPacketReading> *currentRead;

- (void)_headersPacketDidComplete:(NSNotification *)notification;

- (void)_bodyReadPacketDidReceiveData:(NSNotification *)notification;
- (void)_bodyReadPacketDidComplete:(NSNotification *)notification;
@end

@implementation AFHTTPMessagePacket

@synthesize message=_message, bodyStorage=_bodyStorage, bodyStream=_bodyStream, currentRead=_currentRead;

- (id)initForRequest:(BOOL)isRequest {
	self = [self init];
	if (self == nil) return nil;
	
	_message = (CFHTTPMessageRef)CFMakeCollectable(CFHTTPMessageCreateEmpty(kCFAllocatorDefault, isRequest));
	
	return self;
}

- (void)dealloc {
	if (_message != NULL) {
		CFRelease(_message);
		_message = NULL;
	}
	
	[_bodyStorage release];
	[_bodyStream release];
	
	[_currentRead release];
	
	[super dealloc];
}

- (id)buffer {
	return (id)_message;
}

- (void)_nextPacket {
	if (!CFHTTPMessageIsHeaderComplete(self.message)) {
		AFHTTPHeadersPacket *headersPacket = [[[AFHTTPHeadersPacket alloc] initWithMessage:self.message] autorelease];
		headersPacket->_context = &_AFHTTPMessagePacketHeadersContext;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_headersPacketDidComplete:) name:AFNetworkPacketDidCompleteNotificationName object:headersPacket];
		self.currentRead = headersPacket;
		
		return;
	}
	
	AFHTTPBodyPacket *bodyPacket = [[[AFHTTPBodyPacket alloc] initWithMessage:self.message] autorelease];
	bodyPacket->_context = &_AFHTTPMessagePacketBodyContext;
	
	if (self.bodyStorage != nil) {
		[[NSFileManager defaultManager] createDirectoryAtPath:[[[self bodyStorage] URLByDeletingLastPathComponent] path] withIntermediateDirectories:YES attributes:nil error:NULL];
		
		NSOutputStream *newBodyStream = [NSOutputStream outputStreamWithURL:[self bodyStorage] append:NO];
		self.bodyStream = newBodyStream;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bodyReadPacketDidReceiveData:) name:AFHTTPBodyPacketDidReadNotificationName object:bodyPacket];
		[bodyPacket setAppendBodyDataToMessage:NO];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bodyReadPacketDidComplete:) name:AFNetworkPacketDidCompleteNotificationName object:bodyPacket];
	self.currentRead = bodyPacket;
}

// Note: this is a compound packet, the stream bytes availability is checked in the subpackets

- (void)performRead:(NSInputStream *)readStream {
	do {
		if (self.currentRead == nil) [self _nextPacket];
		[self.currentRead performRead:readStream];
	} while (self.currentRead == nil);
}

- (void)_headersPacketDidComplete:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
	
	if ([[notification userInfo] objectForKey:AFNetworkPacketErrorKey] != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	
	if (![AFHTTPBodyPacket messageHasBody:self.message]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
		return;
	}
	
	self.currentRead = nil;
}

- (void)_bodyReadPacketDidReceiveData:(NSNotification *)notification {
	NSData *bodyData = [[notification userInfo] objectForKey:AFHTTPBodyPacketDidReadDataKey];
	
	NSUInteger currentByte = 0;
	while (currentByte < [bodyData length]) {
		CFRetain(bodyData);
		NSInteger writtenBytes = [self.bodyStream write:((const uint8_t *)[bodyData bytes]) + currentByte maxLength:([bodyData length] - currentByte)];
		CFRelease(bodyData);
		
		if (writtenBytes == -1) {
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  [self.bodyStream streamError], AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:[notification object] userInfo:notificationInfo];
			return;
		}
		
		currentByte += writtenBytes;
	}
}

- (void)_bodyReadPacketDidComplete:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFHTTPBodyPacketDidReadNotificationName object:[notification object]];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
	
	if ([[notification userInfo] objectForKey:AFNetworkPacketErrorKey] != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
}

@end
