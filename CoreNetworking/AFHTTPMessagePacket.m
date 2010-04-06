//
//  AFHTTPMessagePacket.m
//  Amber
//
//  Created by Keith Duncan on 15/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPMessagePacket.h"

#import "AmberFoundation/AmberFoundation.h"

#import "AFHTTPHeadersPacket.h"
#import "AFPacketRead.h"
#import "AFHTTPMessage.h"
#import "AFNetworkConstants.h"

#import "NSData+Additions.h"

NSSTRING_CONTEXT(_AFHTTPMessagePacketHeadersContext);
NSSTRING_CONTEXT(_AFHTTPMessagePacketBodyContext);

@interface AFHTTPMessagePacket ()
@property (readonly) CFHTTPMessageRef message;
@property (retain) AFPacket <AFPacketReading> *currentRead;
@property (retain) NSData *readBuffer;
@end

@implementation AFHTTPMessagePacket

@synthesize message=_message, currentRead=_currentRead, readBuffer=_readBuffer;

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
	
	[_currentRead release];
	[_readBuffer release];
	
	[super dealloc];
}

- (id)buffer {
	return (id)_message;
}

- (AFPacket *)_nextPacket {
	if (!CFHTTPMessageIsHeaderComplete(self.message)) {
		AFHTTPHeadersPacket *headersPacket = [[[AFHTTPHeadersPacket alloc] initWithMessage:self.message] autorelease];
		headersPacket->_context = &_AFHTTPMessagePacketHeadersContext;
		return headersPacket;
	}
	
	NSInteger contentLength = AFHTTPMessageGetExpectedBodyLength(self.message);
	if (contentLength > 0) {
		return [[[AFPacketRead alloc] initWithContext:&_AFHTTPMessagePacketBodyContext timeout:-1 terminator:[NSNumber numberWithInteger:contentLength]] autorelease];
	}
	
	return nil;
}

// Note: this is a compound packet, the stream bytes availability is checked in the subpackets

- (void)performRead:(NSInputStream *)readStream {
	do {
		if (self.currentRead == nil) {
			AFPacket *newPacket = [self _nextPacket];
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:newPacket];
			self.currentRead = newPacket;
			
			// Note: this covers reading a request where there's no body
			if (self.currentRead == nil) {
				[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
				return;
			}
		}
		
		[self.currentRead performRead:readStream];
		
		if (self.readBuffer != nil) {
			BOOL bytesAppended = CFHTTPMessageAppendBytes(self.message, [self.readBuffer bytes], [self.readBuffer length]);
			
			if (!bytesAppended) {
				CFRelease(_message);
				_message = NULL;
				
				NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketParseError userInfo:nil];
				NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
												  error, AFPacketErrorKey,
												  nil];
				[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
				return;
			}
			
			self.readBuffer = nil;
			
			
			[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:self.currentRead];
			
			if (self.currentRead.context == &_AFHTTPMessagePacketBodyContext) {
				[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
				return;
			}
			
			self.currentRead = nil;
		}
	} while (self.currentRead == nil);
	
	return;
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	AFPacket *packet = [notification object];
	
#warning check for the error condition
	
	if ([packet isKindOfClass:[AFHTTPHeadersPacket class]]) return;
	self.readBuffer = packet.buffer;
}

@end
