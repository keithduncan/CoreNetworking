//
//  AFHTTPHeadersPacket.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFHTTPHeadersPacket.h"

#import "AmberFoundation/AmberFoundation.h"

#import "AFPacketRead.h"
#import "AFHTTPMessage.h"
#import "AFNetworkConstants.h"

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

- (void)performRead:(NSInputStream *)readStream {
	do {
		if (self.currentRead == nil) {
			NSMutableData *headersTerminator = [NSMutableData data];
			[headersTerminator appendData:[NSData CRLF]];
			[headersTerminator appendData:[NSData CRLF]];
			
			AFPacketRead *newReadPacket = [[[AFPacketRead alloc] initWithTerminator:headersTerminator] autorelease];
			
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:newReadPacket];
			self.currentRead = newReadPacket;
		}
		
		[self.currentRead performRead:readStream];
	} while (self.currentRead == nil);
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
	
	if ([[notification userInfo] objectForKey:AFPacketErrorKey] != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	
	AFPacketRead *packet = [notification object];
	NSData *buffer = [packet buffer];
	
	CFRetain(buffer);
	BOOL appendBytes = CFHTTPMessageAppendBytes(self.message, [buffer bytes], [buffer length]);
	CFRelease(buffer);
	
	
	if (!appendBytes || !CFHTTPMessageIsHeaderComplete(self.message)) {
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   nil];
		NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorParse userInfo:errorInfo];
		
		NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  error, AFPacketErrorKey,
										  nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
		return;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
}

@end
