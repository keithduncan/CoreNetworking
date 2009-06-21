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
#import "AFHTTPMessagePacket.h"

NSString *const AFHTTPMethodGET = @"GET";
NSString *const AFHTTPMethodPOST = @"POST";
NSString *const AFHTTPMethodPUT = @"PUT";
NSString *const AFHTTPMethodDELETE = @"DELETE";

NSString *const AFNetworkSchemeHTTP = @"http";
NSString *const AFNetworkSchemeHTTPS = @"https";

NSString *const AFHTTPMessageUserAgentHeader = @"User-Agent";
NSString *const AFHTTPMessageContentLengthHeader = @"Content-Length";
NSString *const AFHTTPMessageHostHeader = @"Host";
NSString *const AFHTTPMessageConnectionHeader = @"Connection";

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
@synthesize transactionQueue=_transactionQueue;

+ (Class)lowerLayer {
	return [AFNetworkTransport class];
}

+ (const AFInternetTransportSignature *)transportSignatureForScheme:(NSString *)scheme {
	if ([scheme compare:AFNetworkSchemeHTTP options:NSCaseInsensitiveSearch] == NSOrderedSame) return &AFInternetTransportSignatureHTTP;
	if ([scheme compare:AFNetworkSchemeHTTPS options:NSCaseInsensitiveSearch] == NSOrderedSame) return &AFInternetTransportSignatureHTTPS;
	return [super transportSignatureForScheme:scheme];
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_transactionQueue = [[AFPacketQueue alloc] init];
	[_transactionQueue addObserver:self forKeyPath:@"currentPacket" options:NSKeyValueObservingOptionNew context:&AFHTTPConnectionCurrentTransactionObservationContext];
	
	return self;
}

- (void)dealloc {	
	[_transactionQueue removeObserver:self forKeyPath:@"currentPacket"];
	[_transactionQueue release];
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &AFHTTPConnectionCurrentTransactionObservationContext) {
		AFHTTPTransaction *newPacket = [change objectForKey:NSKeyValueChangeNewKey];
		if (newPacket == nil || [newPacket isEqual:[NSNull null]]) return;
		
		if (newPacket.emptyRequest) {
			[super performRead:[[[AFHTTPMessagePacket alloc] initForRequest:YES] autorelease] forTag:0 withTimeout:-1];
		} else {
			[self performWrite:newPacket.request forTag:0 withTimeout:-1];
		}
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (AFHTTPTransaction *)currentTransaction {
	return self.transactionQueue.currentPacket;
}

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequest:NULL] autorelease];
	[self.transactionQueue enqueuePacket:transaction];
}

- (void)performRead {
	[self performRead:nil forTag:0 withTimeout:-1];
}

- (void)performWrite:(CFHTTPMessageRef)message forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	if ([NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease] == nil) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[NSNumber numberWithUnsignedInteger:[[NSMakeCollectable(CFHTTPMessageCopyBody(message)) autorelease] length]] stringValue]);
	}
	
	CFDataRef messageData = CFHTTPMessageCopySerializedMessage(message);
	[super performWrite:(id)messageData forTag:tag withTimeout:duration];
	CFRelease(messageData);
}

- (NSData *)performMethod:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body {
	NSURL *endpoint = [self peer];
	NSURL *resourcePath = [NSURL URLWithString:([resource isEmpty] ? @"/" : resource) relativeToURL:endpoint];
	
	CFHTTPMessageRef request = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)HTTPMethod, (CFURLRef)resourcePath, kCFHTTPVersion1_1)) autorelease];
	
	CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageHostHeader, (CFStringRef)[endpoint absoluteString]);
	
	for (NSString *currentKey in headers) {
		NSString *currentValue = [headers objectForKey:currentKey];
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)currentKey, (CFStringRef)currentValue);
	}
	
	CFHTTPMessageSetBody(request, (CFDataRef)body);
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequest:request] autorelease];
	[self.transactionQueue enqueuePacket:transaction];
	
	NSData *messageData = [NSMakeCollectable(CFHTTPMessageCopySerializedMessage(request)) autorelease];
	return messageData;
}

@end

@implementation AFHTTPConnection (_Delegate)

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data forTag:(NSUInteger)tag {
	if (self.currentTransaction.response == NULL) return;
	
	[super performRead:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease] forTag:0 withTimeout:-1];
}

- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data forTag:(NSUInteger)tag {
	[(id)self.delegate layer:self didRead:data forTag:0];
	
	[self.transactionQueue dequeued];
	[self.transactionQueue tryDequeue];
}

@end
