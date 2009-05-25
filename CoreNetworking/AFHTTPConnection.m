//
//  AFHTTPConnection.m
//  CoreNetworking
//
//  Created by Keith Duncan on 29/04/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFHTTPConnection.h"

#import "CoreNetworking/CoreNetworking.h"
#import "AmberFoundation/AmberFoundation.h"

#import "AFHTTPTransaction.h"

NSString *const kHTTPMethodGET = @"GET";
NSString *const kHTTPMethodPOST = @"POST";
NSString *const kHTTPMethodPUT = @"PUT";
NSString *const kHTTPMethodDELETE = @"DELETE";

NSString *const AFNetworkSchemeHTTP = @"http";
NSString *const AFNetworkSchemeHTTPS = @"https";

NSSTRING_CONTEXT(AFHTTPConnectionCurrentTransactionObservationContext);

enum {
	_kHTTPConnectionReadHeaders = 0,
	_kHTTPConnectionReadBody = 1,
};
typedef NSUInteger AFHTTPConnectionReadTag;

@interface AFHTTPConnection ()
@property (retain) AFPacketQueue *transactionQueue;
@property (readonly) AFHTTPTransaction *currentTransaction;
@end

@interface AFHTTPConnection (Private)
- (BOOL)_shouldStartTLS;
@end

@implementation AFHTTPConnection

@dynamic delegate;
@synthesize authenticationCredentials=_authenticationCredentials;
@synthesize transactionQueue=_transactionQueue;

static NSString *_AFHTTPConnectionUserAgentFromBundle(NSBundle *bundle) {
	return [NSString stringWithFormat:@"%@/%@", [[bundle displayName] stringByReplacingOccurrencesOfString:@" " withString:@"-"], [[bundle displayVersion] stringByReplacingOccurrencesOfString:@" " withString:@"-"], nil];
}

+ (void)initialize {
	NSBundle *application = [NSBundle mainBundle], *framework = [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier];
	NSString *userAgent = [NSString stringWithFormat:@"%@ %@", _AFHTTPConnectionUserAgentFromBundle(application), _AFHTTPConnectionUserAgentFromBundle(framework), nil];
	[self setUserAgent:userAgent];
}

+ (const AFNetworkTransportSignature *)transportSignatureForScheme:(NSString *)scheme {
	scheme = [scheme lowercaseString];
	if ([scheme isEqualToString:AFNetworkSchemeHTTP]) return &AFNetworkTransportSignatureHTTP;
	if ([scheme isEqualToString:AFNetworkSchemeHTTPS]) return &AFNetworkTransportSignatureHTTPS;
	return [super transportSignatureForScheme:scheme];
}

static NSString *_AFHTTPConnectionUserAgent = nil;

+ (NSString *)userAgent {
	NSString *agent = nil;
	@synchronized ([AFHTTPConnection class]) {
		agent = [[_AFHTTPConnectionUserAgent retain] autorelease];
	}
	return agent;
}

+ (void)setUserAgent:(NSString *)userAgent {
	@synchronized ([AFHTTPConnection class]) {
		[_AFHTTPConnectionUserAgent release];
		_AFHTTPConnectionUserAgent = [userAgent copy];
	}
}

+ (Class)lowerLayer {
	return [AFNetworkTransport class];
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_transactionQueue = [[AFPacketQueue alloc] init];
	[_transactionQueue addObserver:self forKeyPath:@"currentPacket" options:NSKeyValueObservingOptionNew context:&AFHTTPConnectionCurrentTransactionObservationContext];
	
	return self;
}

- (void)finalize {
	[self setAuthentication:NULL];
	
	[super finalize];
}

- (void)dealloc {
	[self setAuthentication:NULL];
	[_authenticationCredentials release];
	
	[_transactionQueue removeObserver:self forKeyPath:@"currentPacket"];
	[_transactionQueue release];
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &AFHTTPConnectionCurrentTransactionObservationContext) {
		AFHTTPTransaction *newPacket = [change objectForKey:NSKeyValueChangeNewKey];
		if (newPacket == nil || [newPacket isEqual:[NSNull null]]) return;
		
		[self performWrite:newPacket.request forTag:0 withTimeout:-1];
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (CFHTTPAuthenticationRef)authentication {
	return _authentication;
}

- (void)setAuthentication:(CFHTTPAuthenticationRef)authentication {
	if (_authentication != NULL) CFRelease(_authentication);
	
	_authentication = authentication;
	if (authentication == NULL) return;
	
	_authentication = (CFHTTPAuthenticationRef)CFRetain(authentication);
}

- (AFHTTPTransaction *)currentTransaction {
	return self.transactionQueue.currentPacket;
}

- (void)performWrite:(CFHTTPMessageRef)message forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	if ([NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, CFSTR("Content-Length"))) autorelease] == nil) {
		CFHTTPMessageSetHeaderFieldValue(message, CFSTR("Content-Length"), (CFStringRef)[[NSNumber numberWithUnsignedInteger:[[NSMakeCollectable(CFHTTPMessageCopyBody(message)) autorelease] length]] stringValue]);
	}
	
	NSString *agent = [[self class] userAgent];
	if (agent != nil) {
		CFHTTPMessageSetHeaderFieldValue(message, CFSTR("User-Agent"), (CFStringRef)agent);
	}
	
	CFDataRef messageData = CFHTTPMessageCopySerializedMessage(message);
	[super performWrite:(id)messageData forTag:tag withTimeout:duration];
	CFRelease(messageData);
}

- (NSData *)performMethod:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body {
	NSURL *endpoint = [self peer];
	NSURL *resourcePath = [NSURL URLWithString:([resource isEmpty] ? @"/" : resource) relativeToURL:endpoint];
	
	CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)HTTPMethod, (CFURLRef)resourcePath, kCFHTTPVersion1_1);
	CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Host"), (CFStringRef)[endpoint absoluteString]);
	
	for (NSString *currentKey in headers) {
		NSString *currentValue = [headers objectForKey:currentKey];
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)currentKey, (CFStringRef)currentValue);
	}
	
	if (self.authentication != NULL) {
		CFStreamError error;
		Boolean authenticated = CFHTTPMessageApplyCredentialDictionary(request, self.authentication, (CFDictionaryRef)self.authenticationCredentials, &error);
#pragma unused (authenticated)
	}
	
	CFHTTPMessageSetBody(request, (CFDataRef)body);
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequest:request] autorelease];
	[self.transactionQueue enqueuePacket:transaction];
	
	NSData *messageData = (id)[(id)NSMakeCollectable(CFHTTPMessageCopySerializedMessage(request)) autorelease];
	
	CFRelease(request);
	
	return messageData;
}

@end

@implementation AFHTTPConnection (_Delegate)

- (void)layerDidOpen:(id <AFConnectionLayer>)layer {
	if ([self _shouldStartTLS]) {
		NSDictionary *securityOptions = [NSDictionary dictionaryWithObjectsAndKeys:
										 (id)kCFStreamSocketSecurityLevelNegotiatedSSL, (id)kCFStreamSSLLevel,
										 nil];
		
		[self startTLS:securityOptions];
	}
	
	[self.delegate layerDidOpen:self];
}

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data forTag:(NSUInteger)tag {
	[(id)self layer:layer didRead:[NSData data] forTag:_kHTTPConnectionReadHeaders];
}

- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data forTag:(NSUInteger)tag {	
	CFHTTPMessageAppendBytes(self.currentTransaction.response, [data bytes], [data length]);
	
	if (tag == _kHTTPConnectionReadBody) {
		[(id)self.delegate layer:self didRead:(id)self.currentTransaction.response forTag:0];
		
		[self.transactionQueue dequeuePacket];
		return;
	}
	
	if (!CFHTTPMessageIsHeaderComplete(self.currentTransaction.response)) {
		[super performRead:[NSData CRLF] forTag:_kHTTPConnectionReadHeaders withTimeout:-1];
	} else {
		NSInteger contentLength = [self.currentTransaction responseBodyLength];
		[super performRead:[NSNumber numberWithInteger:contentLength] forTag:_kHTTPConnectionReadBody withTimeout:-1];
	}
}

@end

@implementation AFHTTPConnection (Private)

- (BOOL)_shouldStartTLS {
	NSURL *peer = [self peer];
	
	if (CFGetTypeID([(id)self.lowerLayer peer]) == CFHostGetTypeID()) {
		return [[[peer scheme] lowercaseString] isEqualToString:AFNetworkSchemeHTTPS];
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"%s, cannot determine wether to start TLS.", __PRETTY_FUNCTION__, nil];
	return NO;
}

@end
