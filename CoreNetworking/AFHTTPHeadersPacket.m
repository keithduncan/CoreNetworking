//
//  AFHTTPHeadersPacket.m
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFHTTPHeadersPacket.h"

#import "AFNetworkPacketRead.h"
#import "AFHTTPMessage.h"

#import "AFNetwork-Constants.h"
#import "AFNetwork-Macros.h"

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
@property (assign, nonatomic) AFNETWORK_STRONG CFHTTPMessageRef message;
@property (retain, nonatomic) AFNetworkPacket <AFNetworkPacketReading> *currentRead;

- (void)_observePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet;
- (void)_unobservePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet;
- (void)_observeAndSetCurrentPacket:(AFNetworkPacket <AFNetworkPacketReading> *)newPacket;
- (void)_unobserveAndClearCurrentPacket;
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
	
	[self _unobservePacket:_currentRead];
	[_currentRead release];
	
	[super dealloc];
}

- (void)_observePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readPacketDidComplete:) name:AFNetworkPacketDidCompleteNotificationName object:packet];
}

- (void)_unobservePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:packet];
}

- (void)_observeAndSetCurrentPacket:(AFNetworkPacket <AFNetworkPacketReading> *)newPacket {
	[self _unobserveAndClearCurrentPacket];
	
	[self _observePacket:newPacket];
	self.currentRead = newPacket;
}

- (void)_unobserveAndClearCurrentPacket {
	AFNetworkPacket <AFNetworkPacketReading> *currentPacket = [[self.currentRead retain] autorelease];
	if (currentPacket == nil) {
		return;
	}
	
	[self _unobservePacket:currentPacket];
	self.currentRead = nil;
}

- (NSInteger)performRead:(NSInputStream *)readStream {
	NSInteger currentBytesRead = 0;
	
	do {
		if (self.currentRead == nil) {
			NSData *headersTerminator = [NSData dataWithBytes:"\r\n\r\n" length:4];
			AFNetworkPacketRead *newReadPacket = [[[AFNetworkPacketRead alloc] initWithTerminator:headersTerminator] autorelease];
			
			[self _observeAndSetCurrentPacket:newReadPacket];
		}
		
		NSInteger bytesRead = [self.currentRead performRead:readStream];
		if (bytesRead < 0) {
			return -1;
		}
		
		currentBytesRead += bytesRead;
	} while (self.currentRead == nil);
	
	return currentBytesRead;
}

- (void)_readPacketDidComplete:(NSNotification *)notification {
	if ([[notification userInfo] objectForKey:AFNetworkPacketErrorKey] != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return;
	}
	
	
	AFNetworkPacketRead *packet = [notification object];
	NSData *buffer = [packet buffer];
	
	CFRetain(buffer);
	BOOL appendBytes = CFHTTPMessageAppendBytes(self.message, [buffer bytes], [buffer length]);
	CFRelease(buffer);
	
	
	if (!appendBytes || !CFHTTPMessageIsHeaderComplete(self.message)) {
		NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorParse userInfo:nil];
		
		NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  error, AFNetworkPacketErrorKey,
										  nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
		return;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
}

@end
