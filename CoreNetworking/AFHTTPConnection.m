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

NSString *const AFHTTPMessageUserAgentHeader = @"User-Agent";
NSString *const AFHTTPMessageContentLengthHeader = @"Content-Length";
NSString *const AFHTTPMessageHostHeader = @"Host";
NSString *const AFHTTPMessageConnectionHeader = @"Connection";

NSInteger AFHTTPMessageHeaderLength(CFHTTPMessageRef message) {
	if (!CFHTTPMessageIsHeaderComplete(message)) {
		return -1;
	}
	
	NSString *contentLengthHeaderValue = [NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease];
	
	if (contentLengthHeaderValue == nil) {
		return -1;
	}
	
	NSInteger contentLength = [contentLengthHeaderValue integerValue];
	return contentLength;
}

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
		
		if (newPacket.response == NULL) {
			[self layer:self.lowerLayer didRead:[NSData data] forTag:_kHTTPConnectionReadHeaders];
		} else {
			[self connectionWillPerformRequest:newPacket.request];
			[self performWrite:newPacket.request forTag:0 withTimeout:-1];
		}
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (AFHTTPTransaction *)currentTransaction {
	return self.transactionQueue.currentPacket;
}

- (void)performWrite:(CFHTTPMessageRef)message forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
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

- (void)connectionWillPerformRequest:(CFHTTPMessageRef)request {
	if ([NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(request, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease] == nil) {
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[NSNumber numberWithUnsignedInteger:[[NSMakeCollectable(CFHTTPMessageCopyBody(request)) autorelease] length]] stringValue]);
	}
}

- (void)performRead {
	[self performRead:nil forTag:0 withTimeout:-1];
}

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequest:NULL] autorelease];
	[self.transactionQueue enqueuePacket:transaction];
}

@end

@implementation AFHTTPConnection (_Delegate)

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data forTag:(NSUInteger)tag {
	if (self.currentTransaction.response == NULL) return;
	[(id)self layer:layer didRead:[NSData data] forTag:_kHTTPConnectionReadHeaders];
}

- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data forTag:(NSUInteger)tag {
	CFHTTPMessageRef currentMessage = (self.currentTransaction.response == NULL ? self.currentTransaction.request : self.currentTransaction.response);
	
	NSParameterAssert(currentMessage != NULL);
	NSParameterAssert(data != nil);
	
	CFHTTPMessageAppendBytes(currentMessage, [data bytes], [data length]);
	
	if (tag == _kHTTPConnectionReadBody) {
		[(id)self.delegate layer:self didRead:(id)currentMessage forTag:0];
		
		[self.transactionQueue dequeuePacket];
		return;
	}
	
	if (!CFHTTPMessageIsHeaderComplete(currentMessage)) {
		[super performRead:[NSData CRLF] forTag:_kHTTPConnectionReadHeaders withTimeout:-1];
	} else {
		NSInteger contentLength = AFHTTPMessageHeaderLength(currentMessage);
		
		if (contentLength != -1) {
			[super performRead:[NSNumber numberWithInteger:contentLength] forTag:_kHTTPConnectionReadBody withTimeout:-1];
		} else {
			[self layer:layer didRead:[NSData data] forTag:_kHTTPConnectionReadBody];
		}
	}
}

@end
