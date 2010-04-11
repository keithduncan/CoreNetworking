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
#import "AFPacketReadToWriteStream.h"
#import "AFHTTPMessage.h"
#import "AFNetworkConstants.h"

#import "NSData+Additions.h"

NSSTRING_CONTEXT(_AFHTTPMessagePacketHeadersContext);
NSSTRING_CONTEXT(_AFHTTPMessagePacketBodyContext);

@interface AFHTTPMessagePacket ()
@property (readonly) CFHTTPMessageRef message;
@property (readwrite, copy) NSURL *bodyStorage;
@property (retain) AFPacket <AFPacketReading> *currentRead;
@end

@implementation AFHTTPMessagePacket

@synthesize message=_message, bodyStorage=_bodyStorage, currentRead=_currentRead;

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
	
	[_currentRead release];
	
	[super dealloc];
}

- (void)downloadBodyToURL:(NSURL *)URL {
	[self setBodyStorage:URL];
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
	if (contentLength <= 0) return nil;
	
	if ([self bodyStorage] != nil) {
		NSOutputStream *writeStream = [NSOutputStream outputStreamWithURL:[self bodyStorage] append:NO];
		return [[[AFPacketReadToWriteStream alloc] initWithContext:NULL timeout:-1 writeStream:writeStream numberOfBytesToRead:contentLength] autorelease];
	}
	
	return [[[AFPacketRead alloc] initWithContext:&_AFHTTPMessagePacketBodyContext timeout:-1 terminator:[NSNumber numberWithInteger:contentLength]] autorelease];
}

// Note: this is a compound packet, the stream bytes availability is checked in the subpackets

- (void)performRead:(NSInputStream *)readStream {
	do {
		if (self.currentRead == nil) {
			AFPacket *newPacket = [self _nextPacket];
			
			// Note: this covers reading a request where there's no body
			if (newPacket == nil) {
				[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
				return;
			}
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:newPacket];
			self.currentRead = newPacket;
		}
		
		[self.currentRead performRead:readStream];
	} while (self.currentRead == nil);
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	AFPacket *packet = [notification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:packet];
	
	if ([[notification userInfo] objectForKey:AFPacketErrorKey] != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	if ([packet isKindOfClass:[AFHTTPHeadersPacket class]]) {
		self.currentRead = nil;
		return;
	}
	
	if ([packet isKindOfClass:[AFPacketRead class]]) {
		BOOL bytesAppended = CFHTTPMessageAppendBytes(self.message, [[packet buffer] bytes], [[packet buffer] length]);
		
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
		
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
	}
	
	if ([packet isKindOfClass:[AFPacketReadToWriteStream class]]) {
		
	}
}

@end
