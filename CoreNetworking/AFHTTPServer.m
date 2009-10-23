//
//  AFHTTPServer.m
//  pangolin
//
//  Created by Keith Duncan on 01/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFHTTPServer.h"

#import "AFNetworkTransport.h"
#import "AFHTTPConnection.h"
#import "AFHTTPMessage.h"

#import "AmberFoundation/AmberFoundation.h"
#import <objc/message.h>

#define ENABLE_REQUEST_LOGGING 1
#define ENABLE_RESPONSE_LOGGING 1

#define kPangolinServerVersion kCFHTTPVersion1_1

NSString *const AFHTTPServerRenderersKey = @"renderers";

@interface AFHTTPServer ()
@property (readwrite, retain) NSArray *renderers;
@end

@interface AFHTTPServer (Private)
- (void)_returnResponse:(CFHTTPMessageRef)response forRequest:(CFHTTPMessageRef)request connection:(id)connection permitKeepAlive:(BOOL)allow;
@end

@implementation AFHTTPServer

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
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	CFHTTPMessageRef response = NULL;
	
	@try {
		NSString *requestMethod = [NSMakeCollectable(CFHTTPMessageCopyRequestMethod(request)) autorelease];
		NSDictionary *requestHeaders = [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(request)) autorelease];
		NSData *requestBody = [NSMakeCollectable(CFHTTPMessageCopyBody(request)) autorelease];
#pragma unused (requestBody)
		
#if ENABLE_REQUEST_LOGGING
		printf("Request:\n\t", nil);
		CFShow(request);
		for (NSString *currentKey in [requestHeaders allKeys])
			printf("\t%s: %s\n", [currentKey UTF8String], [[requestHeaders objectForKey:currentKey] UTF8String], nil);
#endif
		
		// Note: assert that the server implements the request method
		if (![[[self class] _implementedMethods] containsObject:[requestMethod uppercaseString]]) {
			AFHTTPStatusCode responseCode = AFHTTPStatusCodeNotImplemented;
			response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeDescription(responseCode), kPangolinServerVersion)) autorelease];
			
			[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:NO];
			return;
		}
		
		// Note: assert that the client has included the Host: header as required by HTTP/1.1
		if ([requestHeaders objectForCaseInsensitiveKey:AFHTTPMessageHostHeader] == nil) {
			AFHTTPStatusCode responseCode = AFHTTPStatusCodeBadRequest;
			response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeDescription(responseCode), kPangolinServerVersion)) autorelease];
			
			[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:NO];
			return;
		}
		
		// Note: echo the request back to the client
		if ([requestMethod caseInsensitiveCompare:AFHTTPMethodTRACE] == NSOrderedSame) {
			AFHTTPStatusCode responseCode = AFHTTPStatusCodeOK;
			response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeDescription(responseCode), kPangolinServerVersion)) autorelease];
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
		
		AFHTTPStatusCode responseCode = AFHTTPStatusCodeNotFound;
		response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeDescription(responseCode), kPangolinServerVersion)) autorelease];
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
		response = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, AFHTTPStatusCodeDescription(responseCode), kPangolinServerVersion)) autorelease];
		[self _returnResponse:response forRequest:request connection:connection permitKeepAlive:NO];
	}
	
	[pool drain];
}

- (void)layer:(id <AFConnectionLayer>)layer didReceiveError:(NSError *)error {
	[layer close];
}

- (BOOL)socket:(AFNetworkTransport *)socket shouldRemainOpenPendingWrites:(NSUInteger)count {
	return YES;
}

@end

@implementation AFHTTPServer (Private)

- (void)_returnResponse:(CFHTTPMessageRef)response forRequest:(CFHTTPMessageRef)request connection:(id)connection permitKeepAlive:(BOOL)allow {
	NSDictionary *requestHeaders = [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(request)) autorelease];
	
	NSString *connectionValue = [requestHeaders objectForCaseInsensitiveKey:AFHTTPMessageConnectionHeader];
	BOOL keepAlive = (connectionValue != nil && [connectionValue caseInsensitiveCompare:@"close"] != NSOrderedSame) && allow;
	
	if (keepAlive) CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)AFHTTPMessageConnectionHeader, CFSTR("keep-alive"));
	else CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)AFHTTPMessageConnectionHeader, CFSTR("close"));
	
#if ENABLE_RESPONSE_LOGGING
	printf("Response:\n\t", nil);
	CFShow(response);
	NSDictionary *responseHeaders = [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(response)) autorelease];
	for (NSString *currentKey in [responseHeaders allKeys])
		printf("\t%s: %s\n", [currentKey UTF8String], [[responseHeaders objectForKey:currentKey] UTF8String], nil);
	printf("\n");
#endif
	
	[connection performResponse:response];
	
	if (allow && keepAlive) {
		[connection readRequest];
	} else {
		[connection close];
	}
}

@end
