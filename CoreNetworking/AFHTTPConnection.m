//
//  AFHTTPConnection.m
//  CoreNetworking
//
//  Created by Keith Duncan on 29/04/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPConnection.h"

#import "AFNetworkTransport.h"
#import "AFPacketQueue.h"
#import "AFHTTPMessage.h"
#import "AFHTTPTransaction.h"

#import "AFHTTPMessagePacket.h"
#import "AFHTTPFilePacket.h"

#import "AmberFoundation/AmberFoundation.h"

NSSTRING_CONTEXT(_AFHTTPConnectionCurrentTransactionObservationContext);

NSSTRING_CONTEXT(_AFHTTPConnectionReadRequestContext);
NSSTRING_CONTEXT(_AFHTTPConnectionReadResponseContext);

NSSTRING_CONTEXT(_AFHTTPConnectionReadDownloadRequestContext);
NSSTRING_CONTEXT(_AFHTTPConnectionReadDownloadResponseContext);

NSSTRING_CONTEXT(_AFHTTPConnectionWriteResponseContext);

@interface AFHTTPConnection ()
@property (readwrite, retain) NSMutableDictionary *messageHeaders;
@property (retain) AFPacketQueue *transactionQueue;
@property (readonly) AFHTTPTransaction *currentTransaction;
@end

@interface AFHTTPConnection (Private)
- (BOOL)_shouldStartTLS;
@end

@implementation AFHTTPConnection

@dynamic delegate;

@synthesize messageHeaders=_messageHeaders;
@synthesize transactionQueue=_transactionQueue;

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
	
	_transactionQueue = [[AFPacketQueue alloc] init];
	[_transactionQueue addObserver:self forKeyPath:@"currentPacket" options:NSKeyValueObservingOptionNew context:&_AFHTTPConnectionCurrentTransactionObservationContext];
	
	return self;
}

- (void)dealloc {
	[_messageHeaders release];
	
	[_transactionQueue removeObserver:self forKeyPath:@"currentPacket"];
	[_transactionQueue release];
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &_AFHTTPConnectionCurrentTransactionObservationContext) {
		AFHTTPTransaction *newPacket = [change objectForKey:NSKeyValueChangeNewKey];
		if (newPacket == nil || [newPacket isEqual:[NSNull null]]) return;
		
		if (newPacket.emptyRequest) {
			[self readRequest];
		} else {
			[self performWrite:newPacket.request withTimeout:-1 context:NULL];
			[self readResponse];
		}
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (AFHTTPTransaction *)currentTransaction {
	return self.transactionQueue.currentPacket;
}

- (void)performWrite:(CFHTTPMessageRef)message withTimeout:(NSTimeInterval)duration context:(void *)context {
	if ([NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease] == nil) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[NSNumber numberWithUnsignedInteger:[[NSMakeCollectable(CFHTTPMessageCopyBody(message)) autorelease] length]] stringValue]);
	}
	
	for (NSString *currentConnectionHeader in [self.messageHeaders allKeys]) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)currentConnectionHeader, (CFStringRef)[self.messageHeaders objectForKey:currentConnectionHeader]);
	}
	
	CFDataRef messageData = CFHTTPMessageCopySerializedMessage(message);
	[super performWrite:(id)messageData withTimeout:duration context:context];
	CFRelease(messageData);
}

- (void)_performRequest:(CFHTTPMessageRef)request {
	NSURL *endpoint = [self peer];
	CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageHostHeader, (CFStringRef)[endpoint absoluteString]);
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequest:request] autorelease];
	
	[self.transactionQueue enqueuePacket:transaction];
	[self.transactionQueue tryDequeue];
}

- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body {
	NSURL *endpoint = [self peer];
	NSURL *resourcePath = [NSURL URLWithString:([resource isEmpty] ? @"/" : resource) relativeToURL:endpoint];
	
	CFHTTPMessageRef request = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)HTTPMethod, (CFURLRef)resourcePath, kCFHTTPVersion1_1)) autorelease];
	
	for (NSString *currentKey in headers) {
		NSString *currentValue = [headers objectForKey:currentKey];
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)currentKey, (CFStringRef)currentValue);
	}
	
	CFHTTPMessageSetBody(request, (CFDataRef)body);
	
	[self _performRequest:request];
}

- (void)performRequest:(NSURLRequest *)request {
	[self _performRequest:(CFHTTPMessageRef)[NSMakeCollectable(AFHTTPMessageCreateForRequest(request)) autorelease]];
}

- (void)readRequest {
	[super performRead:[[[AFHTTPMessagePacket alloc] initForRequest:YES] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadRequestContext];
}

- (void)performResponse:(CFHTTPMessageRef)message {
	[self performWrite:message withTimeout:-1 context:&_AFHTTPConnectionWriteResponseContext];
}

- (void)readResponse {
	[super performRead:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadResponseContext];
}

@end

@implementation AFHTTPConnection (AFAdditions)

- (void)downloadResource:(NSString *)resource toURL:(NSURL *)location deleteFileOnFailure:(BOOL)deleteFileOnFailure {
	NSURL *endpoint = [self peer];
	NSURL *resourcePath = [NSURL URLWithString:([resource isEmpty] ? @"/" : resource) relativeToURL:endpoint];
	CFHTTPMessageRef request = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)AFHTTPMethodGET, (CFURLRef)resourcePath, kCFHTTPVersion1_1)) autorelease];
	[self performWrite:request withTimeout:-1 context:&_AFHTTPConnectionReadDownloadRequestContext];
	
	[super performRead:[[[AFHTTPFilePacket alloc] initForResponseWithLocation:location] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadDownloadResponseContext];
}

@end

@implementation AFHTTPConnection (_Delegate)

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data context:(void *)context {
	if (context == &_AFHTTPConnectionWriteResponseContext) {
		// nop
	} else {
		if ([self.delegate respondsToSelector:_cmd])
			[self.delegate layer:self didWrite:data context:context];
	}
}

- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data context:(void *)context {
	BOOL dequeue = NO;
	
	if (context == &_AFHTTPConnectionReadRequestContext) {
		if ([self.delegate respondsToSelector:@selector(connection:didReceiveRequest:)])
			[self.delegate connection:self didReceiveRequest:(CFHTTPMessageRef)data];
		
		dequeue = YES;
	} else if (context == &_AFHTTPConnectionReadResponseContext) {
		if ([self.delegate respondsToSelector:@selector(connection:didReceiveResponse:)])
			[self.delegate connection:self didReceiveResponse:(CFHTTPMessageRef)data];
		
		dequeue = YES;
	} else {
		if ([self.delegate respondsToSelector:_cmd])
			[self.delegate layer:self didRead:data context:context];
	}
	
	if (dequeue) {
		[self.transactionQueue dequeued];
		[self.transactionQueue tryDequeue];
	}
}

@end
