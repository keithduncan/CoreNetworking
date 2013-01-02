//
//  AFHTTPServer.m
//  pangolin
//
//  Created by Keith Duncan on 01/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPServer.h"

#import <objc/message.h>

#import "AFNetworkTransport.h"
#import "AFHTTPConnection.h"
#import "AFHTTPMessage.h"
#import "AFHTTPMessageMediaType.h"
#import "AFNetworkPacketClose.h"

#define AF_ENABLE_REQUEST_LOGGING() (1 || [[[[NSProcessInfo processInfo] environment] objectForKey:@"com.thirty-three.corenetworking.http.server.log.requests"] isEqual:@"1"])
#define AF_ENABLE_RESPONSE_LOGGING() (1 || [[[[NSProcessInfo processInfo] environment] objectForKey:@"com.thirty-three.corenetworking.http.server.log.responses"] isEqual:@"1"])

#define kCoreNetworkingHTTPServerVersion kCFHTTPVersion1_1

@interface AFHTTPServer (AFNetworkPrivate)
- (void)_logMessage:(CFHTTPMessageRef)message;
- (void)_returnResponse:(CFHTTPMessageRef)response forRequest:(CFHTTPMessageRef)request connection:(id)connection permitKeepAlive:(BOOL)permitKeepAlive;
@end

@implementation AFHTTPServer

@dynamic delegate;
@synthesize renderers=_renderers;

+ (id)server {
	return [[[self alloc] initWithEncapsulationClass:[AFHTTPConnection class]] autorelease];
}

+ (NSArray *)_implementedMethods {
	static NSArray *knownMethods = nil;
	
	if (knownMethods == nil) {
		knownMethods = [[NSArray alloc] initWithObjects:
						AFHTTPMethodTRACE,
						AFHTTPMethodOPTIONS,
						AFHTTPMethodHEAD,
						AFHTTPMethodGET,
						AFHTTPMethodPUT,
						AFHTTPMethodPOST,
						AFHTTPMethodDELETE,
						nil];
	}
	
	return knownMethods;
}

+ (NSString *)_allowHeaderValue {
	static NSString *allowHeaderValue = nil;
	
	if (allowHeaderValue == nil) {
		allowHeaderValue = [[[[self class] _implementedMethods] componentsJoinedByString:@","] retain];
	}
	
	return allowHeaderValue;
}

- (void)dealloc {
	[_renderers release];
	
	[super dealloc];
}

- (void)configureLayer:(AFHTTPConnection *)layer {
	[super configureLayer:layer];
	
	[layer.messageHeaders setObject:AFHTTPAgentString() forKey:AFHTTPMessageServerHeader];
	[layer readRequest];
}

- (void)networkConnection:(AFHTTPConnection *)connection didReceiveRequest:(CFHTTPMessageRef)request {
	@autoreleasepool {
		CFHTTPMessageRef response = NULL;
		
		NSString *requestMethod = [NSMakeCollectable(CFHTTPMessageCopyRequestMethod(request)) autorelease];
		NSURL *requestURL = [NSMakeCollectable(CFHTTPMessageCopyRequestURL(request)) autorelease];
		__unused NSData *requestBody = [NSMakeCollectable(CFHTTPMessageCopyBody(request)) autorelease];
		
		if (AF_ENABLE_REQUEST_LOGGING()) {
			[self _logMessage:request];
		}
		
		// Note: assert that the client has included the Host: header as required by HTTP/1.1
		if ([NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(request, (CFStringRef)AFHTTPMessageHostHeader)) autorelease] == nil) {
			AFHTTPStatusCode responseCode = AFHTTPStatusCodeBadRequest;
			response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
			
			[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:NO];
			return;
		}
		
		// Note: assert that the server implements the request method
		BOOL requestMethodIsImplemented = [[[self class] _implementedMethods] containsObject:[requestMethod uppercaseString]];
		if (!requestMethodIsImplemented) {
			AFHTTPStatusCode responseCode = AFHTTPStatusCodeNotImplemented;
			response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
			
			CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)AFHTTPMessageAllowHeader, (CFStringRef)[[self class] _allowHeaderValue]);
			
			[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:NO];
			return;
		}
		
		// Note: top level server queries for * should probably be directed to a specific renderer
		// Note: should these always be answered by this endpoint, or should they be forwardable to a host specified in the Host header?
		if ([[requestURL lastPathComponent] isEqualToString:@"*"]) {
			if ([requestMethod caseInsensitiveCompare:AFHTTPMethodOPTIONS] == NSOrderedSame) {
				AFHTTPStatusCode responseCode = AFHTTPStatusCodeOK;
				response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
				
				CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)AFHTTPMessageAllowHeader, (CFStringRef)[[self class] _allowHeaderValue]);
				
				[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:YES];
			}
			else {
				AFHTTPStatusCode responseCode = AFHTTPStatusCodeNotFound;
				response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
				
				[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:YES];
			}
			return;
		}
		
		// Note: echo the request back to the client
		if ([requestMethod caseInsensitiveCompare:AFHTTPMethodTRACE] == NSOrderedSame) {
			AFHTTPStatusCode responseCode = AFHTTPStatusCodeOK;
			response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
			
			CFHTTPMessageSetBody(response, (CFDataRef)[NSMakeCollectable(CFHTTPMessageCopySerializedMessage(request)) autorelease]);
			CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)AFHTTPMessageContentTypeHeader, CFSTR("message/http"));
			
			[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:YES];
			return;
		}
		
		NSMutableArray *rendererOrder = [NSMutableArray arrayWithArray:self.renderers];
		id <AFHTTPServerDataDelegate> delegate = self.delegate;
		if (delegate != nil && [delegate respondsToSelector:@selector(networkServer:renderResourceForRequest:)]) {
			[rendererOrder addObject:delegate];
		}
		
		for (id <AFHTTPServerRenderer> currentRenderer in rendererOrder) {
			response = [currentRenderer networkServer:self renderResourceForRequest:request];
			
			if (response != NULL) {
				[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:YES];
				return;
			}
		}
		
		AFHTTPStatusCode responseCode = AFHTTPStatusCodeNotFound;
		response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
		[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:YES];
	}
}

- (void)networkLayer:(id <AFNetworkConnectionLayer>)layer didReceiveError:(NSError *)error {
	[layer close];
}

- (BOOL)networkTransportShouldRemainOpenPendingWrites:(AFNetworkTransport *)transport {
	return YES;
}

@end

@implementation AFHTTPServer (AFNetworkPrivate)

- (void)_logMessage:(CFHTTPMessageRef)message {
	fprintf(stderr, (CFHTTPMessageIsRequest(message) ? "Request:\n" : "Response:\n"));
	
	CFShow(message);
	
	CFDictionaryRef messageHeaders = CFHTTPMessageCopyAllHeaderFields(message);
	if (messageHeaders != NULL) {
		for (NSString *currentHeaderKey in (id)messageHeaders) {
			fprintf(stderr, "\t%s: %s\n", [currentHeaderKey UTF8String], [[(id)messageHeaders objectForKey:currentHeaderKey] UTF8String]);
		}
		CFRelease(messageHeaders);
	}
	
	CFDataRef messageBody = CFHTTPMessageCopyBody(message);
	if (messageBody != NULL) {
		NSStringEncoding bodyEncoding = NSUTF8StringEncoding;
		
		do {
			NSString *contentType = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentTypeHeader)) autorelease];
			AFHTTPMessageMediaType *mediaType = AFHTTPMessageParseContentTypeHeader(contentType);
			if (mediaType == nil) {
				break;
			}
			
			NSString *textEncodingName = [[mediaType parameters] objectForKey:@"charset"];
			if (textEncodingName == nil) {
				break;
			}
			
			CFStringEncoding stringEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)textEncodingName);
			if (stringEncoding == kCFStringEncodingInvalidId) {
				break;
			}
			
			bodyEncoding = CFStringConvertEncodingToNSStringEncoding(stringEncoding);
		} while (0);
		
		NSString *bodyString = [[[NSString alloc] initWithData:(id)messageBody encoding:bodyEncoding] autorelease];
		if (bodyString != nil) {
			fprintf(stderr, "%s\n", [bodyString UTF8String]);
		}
		
		CFRelease(messageBody);
	}
}

- (void)_returnResponse:(CFHTTPMessageRef)response forRequest:(CFHTTPMessageRef)request connection:(id)connection permitKeepAlive:(BOOL)permitKeepAlive {
	NSString *connectionValue = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(request, (CFStringRef)AFHTTPMessageConnectionHeader)) autorelease];
	BOOL keepAlive = (connectionValue != nil && [connectionValue caseInsensitiveCompare:@"keep-alive"] == NSOrderedSame) && permitKeepAlive;
	CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)AFHTTPMessageConnectionHeader, (keepAlive ? CFSTR("keep-alive") : CFSTR("close")));
	
#if 0
	NSString *contentLengthValue = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(request, AFHTTPMessageContentLengthHeader)) autorelease];
	if (contentLengthValue == nil) {
		CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)AFHTTPMessageContentLengthHeader, CFSTR("0"));
	}
#endif
	
	if (AF_ENABLE_RESPONSE_LOGGING()) {
		[self _logMessage:response];
	}
	
	[connection performResponseMessage:response];
	
	if (!keepAlive) {
		AFNetworkPacket *closePacket = [[[AFNetworkPacketClose alloc] init] autorelease];
		[connection performWrite:closePacket withTimeout:-1 context:NULL];
		return;
	}
	
	[connection readRequest];
}

@end
