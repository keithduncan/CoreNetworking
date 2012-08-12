//
//  AFHTTPConnection.m
//  CoreNetworking
//
//  Created by Keith Duncan on 29/04/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPConnection.h"

#import "AFNetworkTransport.h"
#import "AFHTTPMessage.h"
#import "AFHTTPMessagePacket.h"
#import "AFNetworkPacketWrite.h"
#import "AFNetworkPacketWriteFromReadStream.h"

#import "AFNetwork-Macros.h"

AFNETWORK_NSSTRING_CONTEXT(_AFHTTPConnectionWriteRequestContext);
AFNETWORK_NSSTRING_CONTEXT(_AFHTTPConnectionWriteResponseContext);

AFNETWORK_NSSTRING_CONTEXT(_AFHTTPConnectionReadRequestContext);
AFNETWORK_NSSTRING_CONTEXT(_AFHTTPConnectionReadResponseContext);

@interface AFHTTPConnection ()
@property (readwrite, retain, nonatomic) NSMutableDictionary *messageHeaders;
@end

#pragma mark -

@implementation AFHTTPConnection

@dynamic delegate;

@synthesize messageHeaders=_messageHeaders;

+ (Class)lowerLayerClass {
	return [AFNetworkTransport class];
}

+ (AFNetworkInternetTransportSignature)transportSignatureForScheme:(NSString *)scheme {
	if ([scheme compare:AFNetworkSchemeHTTP options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		AFNetworkInternetTransportSignature AFNetworkInternetTransportSignatureHTTP = {
			.type = AFNetworkSocketSignatureInternetTCP,
			.port = 80,
		};
		return AFNetworkInternetTransportSignatureHTTP;
	}
	if ([scheme compare:AFNetworkSchemeHTTPS options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		AFNetworkInternetTransportSignature AFNetworkInternetTransportSignatureHTTPS = {
			.type = AFNetworkSocketSignatureInternetTCP,
			.port = 443,
		};
		return AFNetworkInternetTransportSignatureHTTPS;
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

- (void)prepareMessageForTransport:(CFHTTPMessageRef)message {
	do {
		if ([NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease] != nil) {
			break;
		}
		
		NSUInteger requestBodyLength = [[NSMakeCollectable(CFHTTPMessageCopyBody(message)) autorelease] length];
		if (requestBodyLength == 0) {
			//break;
		}
		
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[NSNumber numberWithUnsignedInteger:requestBodyLength] stringValue]);
	} while (0);
	
	for (NSString *currentConnectionHeader in [self.messageHeaders allKeys]) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)currentConnectionHeader, (CFStringRef)[self.messageHeaders objectForKey:currentConnectionHeader]);
	}
	
	if (!CFHTTPMessageIsRequest(message)) {
		// nop
		return;
	}
	
	NSURL *endpoint = [self peer];
	if ([endpoint isKindOfClass:[NSURL class]]) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)AFHTTPMessageHostHeader, (CFStringRef)[endpoint absoluteString]);
	}
}

- (void)processMessageFromTransport:(CFHTTPMessageRef)message {
	if (CFHTTPMessageIsRequest(message)) {
		if ([self.delegate respondsToSelector:@selector(networkConnection:didReceiveRequest:)]) {
			[self.delegate networkConnection:self didReceiveRequest:(CFHTTPMessageRef)message];
		}
		return;
	}
	
	CFIndex responseStatusCode = CFHTTPMessageGetResponseStatusCode(message);
	if (responseStatusCode >= 100 && responseStatusCode <= 199) {
		[self readResponse];
		return;
	}
	
	if ([self.delegate respondsToSelector:@selector(networkConnection:didReceiveResponse:)]) {
		[self.delegate networkConnection:self didReceiveResponse:message];
	}
}

#pragma mark -

- (void)performRequestMessage:(CFHTTPMessageRef)message {
	[self prepareMessageForTransport:message];
	[self performWrite:AFHTTPConnectionPacketForMessage(message) withTimeout:-1 context:&_AFHTTPConnectionWriteRequestContext];
}

- (void)readRequest {
	[self performRead:[[[AFHTTPMessagePacket alloc] initForRequest:YES] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadRequestContext];
}

#pragma mark -

- (void)performResponseMessage:(CFHTTPMessageRef)message {
	[self prepareMessageForTransport:message];
	[self performWrite:AFHTTPConnectionPacketForMessage(message) withTimeout:-1 context:&_AFHTTPConnectionWriteResponseContext];
}

- (void)readResponse {
	[self performRead:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadResponseContext];
}

#pragma mark -

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didWrite:(id)packet context:(void *)context {
	if (context == &_AFHTTPConnectionWriteRequestContext) {
		//nop
	}
	else if (context == &_AFHTTPConnectionWriteResponseContext) {
		//nop
	}
	else {
		[super networkLayer:layer didWrite:packet context:context];
	}
}

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didRead:(id)packet context:(void *)context {
	if (context == &_AFHTTPConnectionReadRequestContext) {
		CFHTTPMessageRef message = (CFHTTPMessageRef)[(AFHTTPMessagePacket *)packet buffer];
		[self processMessageFromTransport:message];
	}
	else if (context == &_AFHTTPConnectionReadResponseContext) {
		CFHTTPMessageRef message = (CFHTTPMessageRef)[(AFHTTPMessagePacket *)packet buffer];
		[self processMessageFromTransport:message];
	}
	else {
		[super networkLayer:layer didRead:packet context:context];
	}
}

@end
