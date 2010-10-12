//
//  AFHTTPConnection.m
//  CoreNetworking
//
//  Created by Keith Duncan on 29/04/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPConnection.h"

#import "AmberFoundation/AmberFoundation.h"

#import "AFNetworkTransport.h"
#import "AFHTTPMessage.h"
#import "AFHTTPMessagePacket.h"
#import "AFPacketWrite.h"
#import "AFPacketWriteFromReadStream.h"

NSSTRING_CONTEXT(_AFHTTPConnectionWriteRequestContext);
NSSTRING_CONTEXT(_AFHTTPConnectionWriteResponseContext);

NSSTRING_CONTEXT(_AFHTTPConnectionReadRequestContext);
NSSTRING_CONTEXT(_AFHTTPConnectionReadResponseContext);

@interface AFHTTPConnection ()
@property (readwrite, retain) NSMutableDictionary *messageHeaders;
@end

#pragma mark -

@implementation AFHTTPConnection

@dynamic delegate;

@synthesize messageHeaders=_messageHeaders;

+ (Class)lowerLayer {
	return [AFNetworkTransport class];
}

+ (AFInternetTransportSignature)transportSignatureForScheme:(NSString *)scheme {
	if ([scheme compare:AFNetworkSchemeHTTP options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		AFInternetTransportSignature AFInternetTransportSignatureHTTP = {
			.type = AFSocketSignatureNetworkTCP,
			.port = 80,
		};
		
		return AFInternetTransportSignatureHTTP;
	}
	if ([scheme compare:AFNetworkSchemeHTTPS options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		AFInternetTransportSignature AFInternetTransportSignatureHTTPS = {
			.type = AFSocketSignatureNetworkTCP,
			.port = 443,
		};
		
		return AFInternetTransportSignatureHTTPS;
	}
	return [super transportSignatureForScheme:scheme];
}

+ (NSString *)serviceDiscoveryType {
	return @"_http";
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_messageHeaders = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)dealloc {
	[_messageHeaders release];
	
	[super dealloc];
}

- (void)preprocessRequest:(CFHTTPMessageRef)request {
	if ([NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(request, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease] == nil) {
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[NSNumber numberWithUnsignedInteger:[[NSMakeCollectable(CFHTTPMessageCopyBody(request)) autorelease] length]] stringValue]);
	}
	
	for (NSString *currentConnectionHeader in [self.messageHeaders allKeys]) {
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)currentConnectionHeader, (CFStringRef)[self.messageHeaders objectForKey:currentConnectionHeader]);
	}
	
	NSURL *endpoint = [self peer];
	if ([endpoint isKindOfClass:[NSURL class]]) {
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageHostHeader, (CFStringRef)[endpoint host]);
	}
}

#pragma mark -

- (void)performRequestMessage:(CFHTTPMessageRef)message {
	[self preprocessRequest:message];
	[self performWrite:AFHTTPConnectionPacketForMessage(message) withTimeout:-1 context:&_AFHTTPConnectionWriteRequestContext];
}

- (void)readRequest {
	[self performRead:[[[AFHTTPMessagePacket alloc] initForRequest:YES] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadRequestContext];
}

- (void)downloadRequest:(NSURL *)location {
	NSParameterAssert([location isFileURL]);
	
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void)performResponseMessage:(CFHTTPMessageRef)message {
	[self performWrite:AFHTTPConnectionPacketForMessage(message) withTimeout:-1 context:&_AFHTTPConnectionWriteResponseContext];
}

- (void)readResponse {
	[self performRead:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadResponseContext];
}

- (void)downloadResponse:(NSURL *)location {
	NSParameterAssert([location isFileURL]);
	
	AFHTTPMessagePacket *messagePacket = [[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease];
	[messagePacket setBodyStorage:location];
	[self performRead:messagePacket withTimeout:-1 context:&_AFHTTPConnectionReadResponseContext];
}

#pragma mark -

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data context:(void *)context {
	if (context == &_AFHTTPConnectionWriteRequestContext) {
		// nop
	} else if (context == &_AFHTTPConnectionWriteResponseContext) {
		// nop
	} else if ([self.delegate respondsToSelector:_cmd]) {
		[self.delegate layer:self didWrite:data context:context];
	}
}

- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data context:(void *)context {
	if (context == &_AFHTTPConnectionReadRequestContext) {
		if ([self.delegate respondsToSelector:@selector(connection:didReceiveRequest:)])
			[self.delegate connection:self didReceiveRequest:(CFHTTPMessageRef)data];
	} else if (context == &_AFHTTPConnectionReadResponseContext) {
		if ([self.delegate respondsToSelector:@selector(connection:didReceiveResponse:)])
			[self.delegate connection:self didReceiveResponse:(CFHTTPMessageRef)data];
	} else if ([self.delegate respondsToSelector:_cmd]) {
		[self.delegate layer:self didRead:data context:context];
	}
}

@end
