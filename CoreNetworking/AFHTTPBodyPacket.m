//
//  AFHTTPBodyPacket.m
//  TwitterLiveStream
//
//  Created by Keith Duncan on 23/09/2010.
//  Copyright 2010 Realmac Software. All rights reserved.
//

#import "AFHTTPBodyPacket.h"

#import "AmberFoundation/AmberFoundation.h"
#import "CoreNetworking/CoreNetworking.h"

NSSTRING_CONSTANT(AFHTTPBodyPacketDidReadNotificationName);
NSSTRING_CONSTANT(AFHTTPBodyPacketDidReadDataKey);

@interface AFHTTPBodyPacket ()
- (id)initWithMessage:(CFHTTPMessageRef)message;

@property (retain) CFHTTPMessageRef message __attribute__((NSObject));
@property (retain) AFPacket <AFPacketReading> *currentPacket;

- (BOOL)_processDidCompleteNotification:(NSNotification *)notification;
- (BOOL)_appendCurrentBuffer;
@end

#pragma mark -

@interface _AFHTTPBodyChunkedPacket : AFHTTPBodyPacket

- (void)_startChunkRead;
- (void)_chunkSizePacketDidComplete:(NSNotification *)notification;
- (void)_chunkDataPacketDidComplete:(NSNotification *)notification;
- (void)_startChunkFooterRead:(SEL)completionSelector;
- (void)_chunkFooterDidComplete:(NSNotification *)notification;
- (void)_chunksDidComplete:(NSNotification *)notification;

@end

@implementation _AFHTTPBodyChunkedPacket

- (void)performRead:(NSInputStream *)inputStream {
	do {
		if ([self currentPacket] == nil) [self _startChunkRead];
		[[self currentPacket] performRead:inputStream];
	} while ([self currentPacket] == nil);
}

- (void)_startChunkRead {
	AFPacketRead *newlinePacket = [[[AFPacketRead alloc] initWithContext:NULL timeout:-1 terminator:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_chunkSizePacketDidComplete:) name:AFPacketDidCompleteNotificationName object:newlinePacket];
	[self setCurrentPacket:newlinePacket];
}

- (void)_chunkSizePacketDidComplete:(NSNotification *)notification {
	if (![self _processDidCompleteNotification:notification]) return;
	
	NSString *sizeString = [[[[NSString alloc] initWithData:[[self currentPacket] buffer] encoding:NSUTF8StringEncoding] autorelease] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	NSRange parametersSeparator = [sizeString rangeOfString:@";"];
	if (parametersSeparator.location != NSNotFound) sizeString = [sizeString substringToIndex:parametersSeparator.location];
	
	unsigned packetSize = 0;
	[[NSScanner scannerWithString:sizeString] scanHexInt:&packetSize];
	if (packetSize == 0) {
		[self _startChunkFooterRead:@selector(_chunksDidComplete:)];
		return;
	}
	
	AFPacketRead *chunkDataPacket = [[AFPacketRead alloc] initWithContext:NULL timeout:-1 terminator:[NSNumber numberWithInteger:packetSize]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_chunkDataPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:chunkDataPacket];
	[self setCurrentPacket:chunkDataPacket];
}

- (void)_chunkDataPacketDidComplete:(NSNotification *)notification {
	if (![self _processDidCompleteNotification:notification]) return;
	
	if (![self _appendCurrentBuffer]) return;	
	
	[self _startChunkFooterRead:@selector(_chunkFooterDidComplete:)];
}

- (void)_startChunkFooterRead:(SEL)completionSelector {
	AFPacketRead *newlinePacket = [[[AFPacketRead alloc] initWithContext:NULL timeout:-1 terminator:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:completionSelector name:AFPacketDidCompleteNotificationName object:newlinePacket];
	[self setCurrentPacket:newlinePacket];
}

- (void)_chunkFooterDidComplete:(NSNotification *)notification {
	if (![self _processDidCompleteNotification:notification]) return;
	
	[self setCurrentPacket:nil];
}

- (void)_chunksDidComplete:(NSNotification *)notification {
	if (![self _processDidCompleteNotification:notification]) return;
	
#warning 
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
}

@end

#pragma mark -

@implementation AFHTTPBodyPacket

@synthesize message=_message, currentPacket=_currentPacket;
@synthesize appendBodyDataToMessage=_appendBodyDataToMessage;

/*
 This is based on the order of precedence documented in IETF RFC 2616 §4.4 http://tools.ietf.org/html/rfc2616
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
		if ([contentLength integerValue] <= 0) return NO;
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
		} else if ([transferEncoding caseInsensitiveCompare:@"chunked"] == NSOrderedSame) {
			return [[[_AFHTTPBodyChunkedPacket alloc] initWithMessage:message] autorelease];
		} else {
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
		AFHTTPBodyPacket *packet = [[[AFHTTPBodyPacket alloc] initWithMessage:message] autorelease];
		AFPacket *dataPacket = [[[AFPacketRead alloc] initWithContext:NULL timeout:-1 terminator:[NSNumber numberWithInteger:[contentLength integerValue]]] autorelease];
		[[NSNotificationCenter defaultCenter] addObserver:packet selector:@selector(_dataPacketDidComplete:) name:AFPacketDidCompleteNotificationName object:dataPacket];
		[packet setCurrentPacket:dataPacket];
		return packet;
	}
	
	NSString *contentType = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentTypeHeader)) autorelease];
	if ([[contentType lowercaseString] hasPrefix:@"multipart/byteranges"]) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot parse range size", __PRETTY_FUNCTION__];
#warning fix this to parse the range size
		return nil;
	}
	
	if (errorRef != NULL) {
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   
								   nil];
		*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:0 userInfo:errorInfo];
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
	[_currentPacket release];
	
	[super dealloc];
}

- (void)performRead:(NSInputStream *)inputStream {
	[[self currentPacket] performRead:inputStream];
}

- (BOOL)_processDidCompleteNotification:(NSNotification *)notification {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:[notification name] object:[notification object]];
	
	if ([[notification userInfo] objectForKey:AFPacketErrorKey] != nil) {
		[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:[notification userInfo]];
		return NO;
	}
	
	return YES;
}

- (void)_dataPacketDidComplete:(NSNotification *)notification {
	if (![self _processDidCompleteNotification:notification]) return;
	if (![self _appendCurrentBuffer]) return;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self];
}

- (BOOL)_appendCurrentBuffer {
	NSDictionary *dataNotificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  [[self currentPacket] buffer], AFHTTPBodyPacketDidReadDataKey,
										  nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:AFHTTPBodyPacketDidReadNotificationName object:self userInfo:dataNotificationInfo];
	
	
	if ([self appendBodyDataToMessage]) {
		NSData *currentBuffer = [[self currentPacket] buffer];
		
		CFRetain(currentBuffer);
		Boolean appendBytes = CFHTTPMessageAppendBytes([self message], (const UInt8 *)[currentBuffer bytes], [currentBuffer length]);
		CFRelease(currentBuffer);
		
		if (!appendBytes) {
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									   nil];
			NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkPacketErrorParse userInfo:errorInfo];
			
			NSDictionary *notificationInfo = [NSDictionary dictionaryWithObjectsAndKeys:
											  error, AFPacketErrorKey,
											  nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:AFPacketDidCompleteNotificationName object:self userInfo:notificationInfo];
			return NO;
		}
	}
	
	
	return YES;
}

@end
