//
//  AFHTTPMessagePacket.m
//  Amber
//
//  Created by Keith Duncan on 15/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFHTTPMessagePacket.h"

#import "AFPacketRead.h"
#import "AFHTTPConnection.h"

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

enum {
	_kHTTPConnectionReadHeaders = 0,
	_kHTTPConnectionReadBody = 1,
};
typedef NSUInteger AFHTTPConnectionReadTag;

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
		CFRetain(_message);
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
		return [[[AFPacketRead alloc] initWithTag:_kHTTPConnectionReadHeaders timeout:-1 terminator:[NSData CRLF]] autorelease];
	}
	
	NSInteger contentLength = AFHTTPMessageGetHeaderLength(self.message);
	if (contentLength != -1) {
		return [[[AFPacketRead alloc] initWithTag:_kHTTPConnectionReadBody timeout:-1 terminator:[NSNumber numberWithInteger:contentLength]] autorelease];
	}
	
	return nil;
}

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
			CFHTTPMessageAppendBytes(self.message, [self.currentRead.buffer bytes], [self.currentRead.buffer length]);
			
			if (self.currentRead.tag == _kHTTPConnectionReadBody) return YES;
			self.currentRead = nil;
		}
	} while (shouldContinue && self.currentRead == nil);
	
	return NO;
}

@end
