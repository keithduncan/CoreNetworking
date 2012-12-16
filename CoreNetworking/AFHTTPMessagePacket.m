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

#import "AFNetwork-Constants.h"
#import "AFNetwork-Macros.h"

AFNETWORK_NSSTRING_CONTEXT(_AFHTTPMessagePacketHeadersContext);
AFNETWORK_NSSTRING_CONTEXT(_AFHTTPMessagePacketBodyContext);

@interface AFHTTPMessagePacket ()
@property (readonly, nonatomic) AFNETWORK_STRONG CFHTTPMessageRef message;

@property (readwrite, retain, nonatomic) NSOutputStream *bodyStream;

enum {
	AFHTTPMessagePacketStateNone = 0,
	AFHTTPMessagePacketStateHeaders,
	AFHTTPMessagePacketStateBody,
};
typedef NSUInteger AFHTTPMessagePacketState;
@property (assign, nonatomic) AFHTTPMessagePacketState state;

@property (retain, nonatomic) AFNetworkPacket <AFNetworkPacketReading> *currentRead;

- (id <AFNetworkPacketReading>)_nextPacket;

- (void)_observePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet;
- (void)_unobservePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet;
- (void)_unobserveAndClearCurrentPacket;
- (void)_observeAndSetCurrentPacket:(AFNetworkPacket <AFNetworkPacketReading> *)newPacket;

- (void)_headersPacketDidComplete:(NSNotification *)notification;

- (void)_bodyReadPacketDidReceiveData:(NSNotification *)notification;
- (void)_bodyReadPacketDidComplete:(NSNotification *)notification;
@end

@implementation AFHTTPMessagePacket

@synthesize message=_message, bodyStorage=_bodyStorage, bodyStream=_bodyStream, state=_state, currentRead=_currentRead;

- (id)initForRequest:(BOOL)isRequest {
	self = [self init];
	if (self == nil) return nil;
	
	_message = (CFHTTPMessageRef)CFMakeCollectable(CFHTTPMessageCreateEmpty(kCFAllocatorDefault, isRequest));
	
	return self;
}

- (void)dealloc {
	if (_message != NULL) {
		CFRelease(_message);
	}
	
	[_bodyStorage release];
	[_bodyStream release];
	
	[self _unobservePacket:_currentRead];
	[_currentRead release];
	
	[super dealloc];
}

- (id)buffer {
	return (id)_message;
}

- (id <AFNetworkPacketReading>)_nextPacket {
	if (self.state == AFHTTPMessagePacketStateNone) {
		self.state = AFHTTPMessagePacketStateHeaders;
		
		if (!CFHTTPMessageIsHeaderComplete(self.message)) {
			AFHTTPHeadersPacket *headersPacket = [[[AFHTTPHeadersPacket alloc] initWithMessage:self.message] autorelease];
			headersPacket->_context = &_AFHTTPMessagePacketHeadersContext;
			return headersPacket;
		}
		
		// fallthrough
	}
	
	if (self.state == AFHTTPMessagePacketStateHeaders) {
		self.state = AFHTTPMessagePacketStateBody;
		
		NSError *bodyPacketError = nil;
		AFHTTPBodyPacket *bodyPacket = [AFHTTPBodyPacket parseBodyPacketFromMessage:self.message error:&bodyPacketError];
		if (bodyPacket == nil) {
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  bodyPacketError, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			
			return nil;
		}
		
		bodyPacket->_context = &_AFHTTPMessagePacketBodyContext;
		
		if (self.bodyStorage != nil) {
			[[NSFileManager defaultManager] createDirectoryAtPath:[[[self bodyStorage] URLByDeletingLastPathComponent] path] withIntermediateDirectories:YES attributes:nil error:NULL];
			
			NSOutputStream *newBodyStream = [NSOutputStream outputStreamWithURL:[self bodyStorage] append:NO];
			self.bodyStream = newBodyStream;
			
			[bodyPacket setAppendBodyDataToMessage:NO];
		}
		
		return bodyPacket;
	}
	
	return nil;
}

- (void)_observePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet {
	if ([packet isKindOfClass:[AFHTTPHeadersPacket class]]) {
		AFHTTPHeadersPacket *headersPacket = (id)packet;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_headersPacketDidComplete:) name:AFNetworkPacketDidCompleteNotificationName object:headersPacket];
	}
	else if ([packet isKindOfClass:[AFHTTPBodyPacket class]]) {
		AFHTTPBodyPacket *bodyPacket = (id)packet;
		if (self.bodyStream != nil) {
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bodyReadPacketDidReceiveData:) name:AFHTTPBodyPacketDidReadNotificationName object:bodyPacket];
		}
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bodyReadPacketDidComplete:) name:AFNetworkPacketDidCompleteNotificationName object:bodyPacket];
	}
}

- (void)_unobservePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:packet];
}

- (void)_unobserveAndClearCurrentPacket {
	AFNetworkPacket <AFNetworkPacketReading> *currentPacket = self.currentRead;
	if (currentPacket == nil) {
		return;
	}
	
	[self _unobservePacket:currentPacket];
	self.currentRead = nil;
}

- (void)_observeAndSetCurrentPacket:(AFNetworkPacket <AFNetworkPacketReading> *)newPacket {
	[self _unobserveAndClearCurrentPacket];
	
	[self _observePacket:newPacket];
	self.currentRead = newPacket;
}

// Note: this is a compound packet, the stream bytes availability is checked in the subpackets

- (NSInteger)performRead:(NSInputStream *)readStream {
	NSInteger currentBytesRead = 0;
	
	do {
		if (self.currentRead == nil) {
			id <AFNetworkPacketReading> nextPacket = [self _nextPacket];
			if (nextPacket == nil) {
				return -1;
			}
			
			[self _observeAndSetCurrentPacket:nextPacket];
		}
		
		NSInteger bytesRead = [self.currentRead performRead:readStream];
		if (bytesRead < 0) {
			return -1;
		}
		
		currentBytesRead += bytesRead;
	} while (self.currentRead == nil);
	
	return currentBytesRead;
}

- (void)_headersPacketDidComplete:(NSNotification *)notification {
	if ([[notification userInfo] objectForKey:AFNetworkPacketErrorKey] != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	if (![AFHTTPBodyPacket messageHasBody:self.message]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
		return;
	}
	
	// Note: clear headers packet so that the next packet can start
	[self _unobserveAndClearCurrentPacket];
}

- (void)_bodyReadPacketDidReceiveData:(NSNotification *)notification {
	NSData *bodyData = [[notification userInfo] objectForKey:AFHTTPBodyPacketDidReadDataKey];
	
	NSUInteger currentByte = 0;
	while (currentByte < [bodyData length]) {
		CFRetain(bodyData);
		NSInteger writtenBytes = [self.bodyStream write:((uint8_t const *)[bodyData bytes]) + currentByte maxLength:([bodyData length] - currentByte)];
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
	if ([[notification userInfo] objectForKey:AFNetworkPacketErrorKey] != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
	
	// Note: don't clear body packet so that -performRead: doesn't return -1
}

@end
