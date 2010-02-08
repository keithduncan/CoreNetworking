//
//  AFHTTPMessagePacket.m
//  Amber
//
//  Created by Keith Duncan on 15/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFHTTPMessagePacket.h"

#import "AmberFoundation/AmberFoundation.h"

#import "AFPacketRead.h"
#import "AFHTTPMessage.h"
#import "AFNetworkConstants.h"

#import "NSData+Additions.h"

NSInteger AFHTTPMessageGetHeaderLength(CFHTTPMessageRef message) {
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

NSSTRING_CONTEXT(AFHTTPMessagePacketHeadersContext);
NSSTRING_CONTEXT(AFHTTPMessagePacketBodyContext);

@interface AFHTTPMessagePacket ()
@property (readonly) CFHTTPMessageRef message;
@property (retain) AFPacketRead *currentRead;
@end

@implementation AFHTTPMessagePacket

@synthesize message=_message;
@synthesize currentRead=_currentRead;

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
	
	[super dealloc];
}

- (id)buffer {
	return (id)_message;
}

- (AFPacketRead *)_nextReadPacket {
	if (!CFHTTPMessageIsHeaderComplete(self.message)) {
		return [[[AFPacketRead alloc] initWithContext:&AFHTTPMessagePacketHeadersContext timeout:-1 terminator:[NSData CRLF]] autorelease];
	}
	
	NSInteger contentLength = AFHTTPMessageGetHeaderLength(self.message);
	if (contentLength > 0) {
		return [[[AFPacketRead alloc] initWithContext:&AFHTTPMessagePacketBodyContext timeout:-1 terminator:[NSNumber numberWithInteger:contentLength]] autorelease];
	}
	
	return nil;
}

// Note: this is a compound packet, the stream bytes availability is checked in the subpackets

- (BOOL)performRead:(CFReadStreamRef)stream error:(NSError **)errorRef {	
	BOOL shouldContinue = NO;
	do {
		if (self.currentRead == nil) {
			self.currentRead = [self _nextReadPacket];
			
			// Note: this covers reading a request where there's no body
			if (self.currentRead == nil) return YES;
		}
		
		shouldContinue = [self.currentRead performRead:stream error:errorRef];
		
		if (shouldContinue) {
			shouldContinue = CFHTTPMessageAppendBytes(self.message, [self.currentRead.buffer bytes], [self.currentRead.buffer length]);
			
			if (!shouldContinue) {
				CFRelease(_message);
				_message = NULL;
				
				if (errorRef != NULL)
					*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketParseError userInfo:nil];
				
				return YES;
			}
			
			if (self.currentRead.context == &AFHTTPMessagePacketBodyContext) return YES;
			self.currentRead = nil;
		}
	} while (shouldContinue && self.currentRead == nil);
	
	return NO;
}

@end
