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

#define ENABLE_REQUEST_LOGGING 1
#define ENABLE_RESPONSE_LOGGING 1

#define kCoreNetworkingHTTPServerVersion kCFHTTPVersion1_1

@interface AFHTTPServer (Private)
- (void)_logMessage:(CFHTTPMessageRef)message;
- (void)_returnResponse:(CFHTTPMessageRef)response forRequest:(CFHTTPMessageRef)request connection:(id)connection permitKeepAlive:(BOOL)allow;
@end

@implementation AFHTTPServer

@dynamic delegate;
@synthesize renderers=_renderers;

+ (id)server {
	return [[[self alloc] initWithEncapsulationClass:[AFHTTPConnection class]] autorelease];
}

+ (NSArray *)_implementedMethods {
	static NSArray *knownMethods = nil;
	
	if (knownMethods == nil) knownMethods = [[NSArray alloc] initWithObjects:
											 AFHTTPMethodTRACE,
											 AFHTTPMethodOPTIONS,
											 AFHTTPMethodHEAD,
											 AFHTTPMethodGET,
											 AFHTTPMethodPUT,
											 AFHTTPMethodPOST,
											 AFHTTPMethodDELETE,
											 nil];
	
	return knownMethods;
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_renderers = [[NSArray alloc] init];
	
	return self;
}

- (void)dealloc {
	[_renderers release];
	
	[super dealloc];
}

- (void)layerDidOpen:(id)layer {
	// Note: this is a temporary solution to eliminate a compiler warning
	struct objc_super superclass = {
		.receiver = self,
#if !__OBJC2__
		.class
#else 
		.super_class
#endif
			 = [self superclass],
	};
	(void (*)(id, SEL, id))objc_msgSendSuper(&superclass, _cmd, layer);
	if (![layer isKindOfClass:[AFHTTPConnection class]]) return;
	
	AFHTTPConnection *connection = layer;
	
	NSString *serverAgent = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:(id)kCFBundleNameKey], [[NSBundle mainBundle] objectForInfoDictionaryKey:(id)kCFBundleVersionKey], nil];
	[connection.messageHeaders setObject:serverAgent forKey:@"Server"];
	
	[connection readRequest];
}

- (void)connection:(AFHTTPConnection *)connection didReceiveRequest:(CFHTTPMessageRef)request {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	CFHTTPMessageRef response = NULL;
	
	@try {
		NSString *requestMethod = [NSMakeCollectable(CFHTTPMessageCopyRequestMethod(request)) autorelease];
		NSDictionary *requestHeaders = [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(request)) autorelease];
		NSData *requestBody = [NSMakeCollectable(CFHTTPMessageCopyBody(request)) autorelease];
#pragma unused (requestBody)
		
#if ENABLE_REQUEST_LOGGING
		[self _logMessage:request];
#endif
		
		// Note: assert that the server implements the request method
		if (![[[self class] _implementedMethods] containsObject:[requestMethod uppercaseString]]) {
			AFHTTPStatusCode responseCode = AFHTTPStatusCodeNotImplemented;
			response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
			
			[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:NO];
			return;
		}
		
		// Note: assert that the client has included the Host: header as required by HTTP/1.1
		if ([requestHeaders objectForCaseInsensitiveKey:AFHTTPMessageHostHeader] == nil) {
			AFHTTPStatusCode responseCode = AFHTTPStatusCodeBadRequest;
			response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
			
			[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:NO];
			return;
		}
		
		// Note: echo the request back to the client
		if ([requestMethod caseInsensitiveCompare:AFHTTPMethodTRACE] == NSOrderedSame) {
			AFHTTPStatusCode responseCode = AFHTTPStatusCodeOK;
			response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
			CFHTTPMessageSetBody(response, (CFDataRef)[NSMakeCollectable(CFHTTPMessageCopySerializedMessage(request)) autorelease]);
			
			[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:YES];
			return;
		}
		
		// Note: iterate the renderers, allowing each to return a response in turn
		// Note: this could potentially include a layer which calls out to other servers, allowing this server to function as a middleware router
		for (id <AFHTTPServerRenderer> currentRenderer in self.renderers) {
			response = [currentRenderer renderResourceForRequest:request];
			if (response == NULL) continue;
			
			[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:YES];
			return;
		}
		
		if ([[self delegate] respondsToSelector:@selector(server:renderResourceForRequest:)]) {
			response = [[self delegate] server:self renderResourceForRequest:request];
			
			if (response != NULL) {
				[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:YES];
				return;
			}
		}
		
		AFHTTPStatusCode responseCode = AFHTTPStatusCodeNotFound;
		response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
		[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:YES];
	}
	@catch (NSException *exception) {
		printf("*** Caught Response Handling Exception '%s', reason '%s'\n", [[exception name] UTF8String], [[exception reason] UTF8String], nil);
		printf("*** Call Stack at throw:\n(\n", nil);
		NSArray *addresses = [exception callStackReturnAddresses];
		for (NSUInteger index = 0; index < [addresses count]; index++) {
			NSNumber *address = [addresses objectAtIndex:index];
			printf("\t%ld\t0x%qX\n", index, (unsigned long long)[address unsignedIntegerValue], nil);
		}
		printf(")\n", nil);
		
		AFHTTPStatusCode responseCode = AFHTTPStatusCodeServerError;
		response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeGetDescription(responseCode), kCoreNetworkingHTTPServerVersion)) autorelease];
		[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:NO];
	}
	
	[pool drain];
}

- (void)layer:(id <AFConnectionLayer>)layer didReceiveError:(NSError *)error {
	[layer close];
}

- (BOOL)transportShouldRemainOpenPendingWrites:(AFNetworkTransport *)transport {
	return YES;
}

@end

@implementation AFHTTPServer (Private)

- (void)_logMessage:(CFHTTPMessageRef)message {
	fprintf(stderr, (CFHTTPMessageIsRequest(message) ? "Request:\n" : "Response:\n"));
	
	CFShow(message);
	
	CFDictionaryRef messageHeaders = CFHTTPMessageCopyAllHeaderFields(message);
	for (NSString *currentHeaderKey in (id)messageHeaders) fprintf(stderr, "\t%s: %s\n", [currentHeaderKey UTF8String], [[(id)messageHeaders objectForKey:currentHeaderKey] UTF8String]);
	CFRelease(messageHeaders);
}

- (void)_returnResponse:(CFHTTPMessageRef)response forRequest:(CFHTTPMessageRef)request connection:(id)connection permitKeepAlive:(BOOL)allow {
	NSDictionary *requestHeaders = [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(request)) autorelease];
	
	NSString *connectionValue = [requestHeaders objectForCaseInsensitiveKey:AFHTTPMessageConnectionHeader];
	BOOL keepAlive = (connectionValue != nil && [connectionValue caseInsensitiveCompare:@"close"] != NSOrderedSame) && allow;
	
	if (keepAlive) CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)AFHTTPMessageConnectionHeader, CFSTR("keep-alive"));
	else CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)AFHTTPMessageConnectionHeader, CFSTR("close"));
	
#if ENABLE_RESPONSE_LOGGING
	[self _logMessage:response];
#endif
	
	[connection performResponseMessage:response];
	
	if (allow && keepAlive) {
		[connection readRequest];
		return;
	}
	
	[connection close];
}

@end
