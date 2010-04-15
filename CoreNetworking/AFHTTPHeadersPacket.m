//
//  AFHTTPHeadersPacket.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFHTTPHeadersPacket.h"

#import "AFPacketRead.h"
#import "AFHTTPMessage.h"
#import "AFNetworkConstants.h"

#import "NSData+Additions.h"

NSInteger AFHTTPMessageGetExpectedBodyLength(CFHTTPMessageRef message) {
	if (!CFHTTPMessageIsHeaderComplete(message)) {
		return -1;
	}
	
	NSString *contentLengthHeaderValue = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease];
	
	if (contentLengthHeaderValue == nil) {
		return -1;
	}
	
	NSInteger contentLength = [contentLengthHeaderValue integerValue];
	return contentLength;
}

@interface AFHTTPHeadersPacket ()
@property (retain) CFHTTPMessageRef message __attribute__((NSObject));
@property (retain) AFPacketRead *currentRead;
@end

@implementation AFHTTPHeadersPacket

@synthesize message=_message, currentRead=_currentRead;

- (id)initWithMessage:(CFHTTPMessageRef)message {
	self = [self init];
	if (self == nil) return nil;
	
	_message = (CFHTTPMessageRef)CFMakeCollectable(CFRetain(message));
	
	return self;
}

- (void)dealloc {
	if (_message != NULL) {
		CFRelease(_message);
	}
	
	[_currentRead release];
	
	[super dealloc];
}

- (AFPacketRead *)_nextReadPacket {
	return [[[AFPacketRead alloc] initWithContext:NULL timeout:-1 terminator:[NSData CRLF]] autorelease];
}

- (void)performRead:(NSInputStream *)readStream {
	do {
		if (self.currentRead == nil) {
			AFPacketRead *newReadPacket = [self _nextReadPacket];
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:newReadPacket];
			self.currentRead = newReadPacket;
		}
		
		[self.currentRead performRead:readStream];
	} while (self.currentRead == nil);
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	AFPacketRead *packet = [notification object];	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AFPacketDidCompleteNotificationName object:packet];
	
	if ([[notification userInfo] objectForKey:AFPacketErrorKey] != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	BOOL appendBytes = CFHTTPMessageAppendBytes(self.message, [[packet buffer] bytes], [[packet buffer] length]);
	if (!appendBytes) {
		NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorParse userInfo:nil];
		NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  error, AFPacketErrorKey,
										  nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
		return;
	}
	
	if (CFHTTPMessageIsHeaderComplete(self.message)) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
		return;
	}
	
	self.currentRead = nil;
}

@end
