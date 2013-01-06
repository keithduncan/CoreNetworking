//
//  AFHTTPBodyPacket.m
//  TwitterLiveStream
//
//  Created by Keith Duncan on 23/09/2010.
//  Copyright 2010. All rights reserved.
//

#import "AFHTTPBodyPacket.h"

#import "AFHTTPMessage.h"
#import "AFNetworkPacketRead.h"

#import "AFNetwork-Constants.h"
#import "AFNetwork-Macros.h"

AFNETWORK_NSSTRING_CONSTANT(AFHTTPBodyPacketDidReadNotificationName);
AFNETWORK_NSSTRING_CONSTANT(AFHTTPBodyPacketDidReadDataKey);

@interface _AFHTTPBodyChunkedPacket : AFHTTPBodyPacket

- (void)_startChunkRead;
- (void)_chunkSizePacketDidComplete:(NSNotification *)notification;
- (void)_chunkDataPacketDidComplete:(NSNotification *)notification;
- (void)_startChunkFooterRead:(SEL)completionSelector;
- (void)_chunkFooterDidComplete:(NSNotification *)notification;
- (void)_chunksDidComplete:(NSNotification *)notification;

@end

@interface AFHTTPBodyPacket ()
- (id)initWithMessage:(CFHTTPMessageRef)message;

@property (assign, nonatomic) AFNETWORK_STRONG CFHTTPMessageRef message;
@property (retain, nonatomic) AFNetworkPacket <AFNetworkPacketReading> *currentRead;

- (void)_observePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet selector:(SEL)selector;
- (void)_unobservePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet;
- (void)_observeAndSetCurrentPacket:(AFNetworkPacket <AFNetworkPacketReading> *)newPacket selector:(SEL)selector;
- (void)_unobserveAndClearCurrentPacket;

- (BOOL)_checkDidCompleteNotification:(NSNotification *)notification;
- (BOOL)_appendCurrentBuffer;
@end

#pragma mark -

@implementation AFHTTPBodyPacket

@synthesize message=_message, currentRead=_currentRead;
@synthesize appendBodyDataToMessage=_appendBodyDataToMessage;

/*
	This is based on the order of precedence documented in IETF-RFC-2616 §4.4 <http://tools.ietf.org/html/rfc2616>
 */
+ (BOOL)messageHasBody:(CFHTTPMessageRef)message {
	NSParameterAssert(CFHTTPMessageIsHeaderComplete(message));
	
	NSString *transferEncoding = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageTransferEncodingHeader)) autorelease];
	if (transferEncoding != nil) {
		if ([transferEncoding caseInsensitiveCompare:@"identity"] != NSOrderedSame) {
			return YES;
		}
	}
	
	NSString *contentLength = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease];
	if (contentLength != nil) {
		if ([contentLength integerValue] <= 0) {
			return NO;
		}
		return YES;
	}
	
	NSString *contentType = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentTypeHeader)) autorelease];
	if ([[contentType lowercaseString] hasPrefix:@"multipart/byteranges"]) {
		return YES;
	}
	
	return NO;
}

+ (AFHTTPBodyPacket *)parseBodyPacketFromMessage:(CFHTTPMessageRef)message error:(NSError **)errorRef {
	NSString *transferEncoding = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageTransferEncodingHeader)) autorelease];
	if (transferEncoding != nil) {
		if ([transferEncoding caseInsensitiveCompare:@"identity"] == NSOrderedSame) {
			// nop
		}
		else if ([transferEncoding caseInsensitiveCompare:@"chunked"] == NSOrderedSame) {
			return [[[_AFHTTPBodyChunkedPacket alloc] initWithMessage:message] autorelease];
		}
		else {
			if (errorRef != NULL) {
				NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										   [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ is an unknown transfer encoding.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFHTTPBodyPacket parse body packet unknown transfer encoding error failure reason"), transferEncoding], NSLocalizedFailureReasonErrorKey,
										   nil];
				*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorParse userInfo:errorInfo];
			}
			return nil;
		}
	}
	
	NSString *contentLength = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease];
	if (contentLength != nil) {
		NSInteger contentLengthValue = [contentLength integerValue];
		if (contentLengthValue < 0) {
			if (errorRef != NULL) {
				NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										   NSLocalizedStringFromTableInBundle(@"The Content-Length header cannot be negative.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFHTTPBodyPacket parse body packet unknown transfer encoding error failure reason"), NSLocalizedFailureReasonErrorKey,
										   nil];
				*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorParse userInfo:errorInfo];
			}
			return nil;
		}
		
		AFHTTPBodyPacket *bodyPacket = [[[AFHTTPBodyPacket alloc] initWithMessage:message] autorelease];
		
		AFNetworkPacketRead *dataPacket = [[[AFNetworkPacketRead alloc] initWithTerminator:[NSNumber numberWithInteger:contentLengthValue]] autorelease];
		[bodyPacket _observeAndSetCurrentPacket:dataPacket selector:@selector(_dataPacketDidComplete:)];
		
		return bodyPacket;
	}
	
	NSString *contentType = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentTypeHeader)) autorelease];
	if ([[contentType lowercaseString] hasPrefix:@"multipart/byteranges"]) {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%s, cannot parse range size", __PRETTY_FUNCTION__] userInfo:nil];
		// WARNING: fix this to parse the range size
		return nil;
	}
	
	if (errorRef != NULL) {
		*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorUnknown userInfo:nil];
	}
	return nil;
}

- (id)initWithMessage:(CFHTTPMessageRef)message {
	self = [super init];
	if (self == nil) return nil;
	
	_message = (CFHTTPMessageRef)CFMakeCollectable(CFRetain(message));
	
	_appendBodyDataToMessage = YES;
	
	return self;
}

- (void)dealloc {
	CFRelease(_message);
	
	[self _unobservePacket:_currentRead];
	[_currentRead release];
	
	[super dealloc];
}

- (void)_observePacket:(AFNetworkPacket <AFNetworkPacketReading> *)packet selector:(SEL)selector {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:selector name:AFNetworkPacketDidCompleteNotificationName object:packet];
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

- (void)_observeAndSetCurrentPacket:(AFNetworkPacket <AFNetworkPacketReading> *)newPacket selector:(SEL)selector {
	[self _unobserveAndClearCurrentPacket];
	
	[self _observePacket:newPacket selector:selector];
	self.currentRead = newPacket;
}

- (NSInteger)performRead:(NSInputStream *)inputStream {
	return [self.currentRead performRead:inputStream];
}

- (BOOL)_checkDidCompleteNotification:(NSNotification *)notification {
	if ([[notification userInfo] objectForKey:AFNetworkPacketErrorKey] != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return NO;
	}
	
	return YES;
}

- (BOOL)_appendCurrentBuffer {
	NSData *currentBuffer = self.currentRead.buffer;
	
	NSDictionary *dataNotificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  currentBuffer, AFHTTPBodyPacketDidReadDataKey,
										  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFHTTPBodyPacketDidReadNotificationName object:self userInfo:dataNotificationInfo];
	
	if (self.appendBodyDataToMessage) {
		CFRetain(currentBuffer);
		Boolean appendBytes = CFHTTPMessageAppendBytes(self.message, (uint8_t const *)[currentBuffer bytes], [currentBuffer length]);
		CFRelease(currentBuffer);
		
		if (!appendBytes) {
			NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorParse userInfo:nil];
			
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  error, AFNetworkPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return NO;
		}
	}
	
	return YES;
}

- (void)_dataPacketDidComplete:(NSNotification *)notification {
	if (![self _checkDidCompleteNotification:notification]) {
		return;
	}
	if (![self _appendCurrentBuffer]) {
		return;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self];
}

@end

@implementation _AFHTTPBodyChunkedPacket

- (NSInteger)performRead:(NSInputStream *)inputStream {
	NSInteger currentBytesRead = 0;
	
	do {
		if (self.currentRead == nil) {
			[self _startChunkRead];
		}
		
		NSInteger bytesRead = [self.currentRead performRead:inputStream];
		if (bytesRead < 0) {
			return -1;
		}
		
		currentBytesRead += bytesRead;
	} while (self.currentRead == nil);
	
	return currentBytesRead;
}

- (void)_startChunkRead {
	AFNetworkPacketRead *newlinePacket = [[[AFNetworkPacketRead alloc] initWithTerminator:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
	[self _observeAndSetCurrentPacket:newlinePacket selector:@selector(_chunkSizePacketDidComplete:)];
}

- (void)_chunkSizePacketDidComplete:(NSNotification *)notification {
	if (![self _checkDidCompleteNotification:notification]) {
		return;
	}
	
	NSString *sizeString = [[[[NSString alloc] initWithData:self.currentRead.buffer encoding:NSUTF8StringEncoding] autorelease] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSRange parametersSeparator = [sizeString rangeOfString:@";"];
	if (parametersSeparator.location != NSNotFound) {
		sizeString = [sizeString substringToIndex:parametersSeparator.location];
	}
	
	unsigned packetSize = 0;
	[[NSScanner scannerWithString:sizeString] scanHexInt:&packetSize];
	if (packetSize == 0) {
		[self _startChunkFooterRead:@selector(_chunksDidComplete:)];
		return;
	}
	
	AFNetworkPacketRead *chunkDataPacket = [[[AFNetworkPacketRead alloc] initWithTerminator:[NSNumber numberWithInteger:packetSize]] autorelease];
	[self _observeAndSetCurrentPacket:chunkDataPacket selector:@selector(_chunkDataPacketDidComplete:)];
}

- (void)_chunkDataPacketDidComplete:(NSNotification *)notification {
	if (![self _checkDidCompleteNotification:notification]) {
		return;
	}
	
	if (![self _appendCurrentBuffer]) {
		return;
	}
	
	[self _startChunkFooterRead:@selector(_chunkFooterDidComplete:)];
}

- (void)_startChunkFooterRead:(SEL)completionSelector {
	AFNetworkPacketRead *newlinePacket = [[[AFNetworkPacketRead alloc] initWithTerminator:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
	[self _observeAndSetCurrentPacket:newlinePacket selector:completionSelector];
}

- (void)_chunkFooterDidComplete:(NSNotification *)notification {
	if (![self _checkDidCompleteNotification:notification]) {
		return;
	}
	
	[self _unobserveAndClearCurrentPacket];
}

- (void)_chunksDidComplete:(NSNotification *)notification {
	if (![self _checkDidCompleteNotification:notification]) {
		return;
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFNetworkPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
}

@end
