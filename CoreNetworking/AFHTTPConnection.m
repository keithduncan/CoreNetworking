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
#import "AFPacketWrite.h"
#import "AFPacketWriteFromReadStream.h"

#import "AmberFoundation/AmberFoundation.h"

NSSTRING_CONTEXT(_AFHTTPConnectionCurrentTransactionObservationContext);

NSSTRING_CONTEXT(_AFHTTPConnectionWriteRequestContext);
NSSTRING_CONTEXT(_AFHTTPConnectionWriteResponseContext);

NSSTRING_CONTEXT(_AFHTTPConnectionReadRequestContext);
NSSTRING_CONTEXT(_AFHTTPConnectionReadResponseContext);

@interface AFHTTPConnection ()
@property (readwrite, retain) NSMutableDictionary *messageHeaders;
@property (retain) AFPacketQueue *transactionQueue;
@property (readonly) AFHTTPTransaction *currentTransaction;
@end

@interface AFHTTPConnection (Private)
- (CFHTTPMessageRef)_requestForMethod:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body;
- (void)_prepareMessage:(CFHTTPMessageRef)message;
@end

#pragma mark -

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
		
		for (id <AFPacketWriting> currentPacket in [newPacket requestPackets]) {
			[self performWrite:currentPacket withTimeout:-1 context:&_AFHTTPConnectionWriteRequestContext];
		}
		[self readResponse];
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (AFHTTPTransaction *)currentTransaction {
	return self.transactionQueue.currentPacket;
}

- (void)performMessageWrite:(CFHTTPMessageRef)message withTimeout:(NSTimeInterval)duration context:(void *)context {
	[self _prepareMessage:message];
	
	CFDataRef messageData = CFHTTPMessageCopySerializedMessage(message);
	[self performWrite:(id)messageData withTimeout:duration context:context];
	CFRelease(messageData);
}

#pragma mark -

- (void)_performRequest:(NSArray *)packets {
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:packets] autorelease];
	[self.transactionQueue enqueuePacket:transaction];
	[self.transactionQueue tryDequeue];
}

- (AFPacketWrite *)_packetForMessage:(CFHTTPMessageRef)message {
	NSData *messageData = [NSMakeCollectable(CFHTTPMessageCopySerializedMessage(message)) autorelease];
	return [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:messageData] autorelease];
}

- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body {
	AFPacket *requestPacket = [self _packetForMessage:[self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:body]];
	[self _performRequest:[NSArray arrayWithObject:requestPacket]];
}

- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withStream:(NSInputStream *)bodyStream {
	CFHTTPMessageRef request = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	AFPacket *requestPacket = [self _packetForMessage:request];
	
	AFPacketWriteFromReadStream *streamPacket = [[[AFPacketWriteFromReadStream alloc] initWithContext:NULL timeout:-1 readStream:bodyStream numberOfBytesToWrite:-1] autorelease];
	
	[self _performRequest:[NSArray arrayWithObjects:requestPacket, streamPacket, nil]];
}

- (void)performRequest:(NSURLRequest *)request {
	if ([request HTTPBodyStream] != nil) {
		[self performRequest:[request HTTPMethod] onResource:[[request URL] path] withHeaders:[request allHTTPHeaderFields] withStream:[request HTTPBodyStream]];
		return;
	}
	
	[self performRequest:[request HTTPMethod] onResource:[[request URL] path] withHeaders:[request allHTTPHeaderFields] withBody:[request HTTPBody]];
}

- (void)readRequest {
	[self performRead:[[[AFHTTPMessagePacket alloc] initForRequest:YES] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadRequestContext];
}

#pragma mark -

- (void)performResponse:(CFHTTPMessageRef)message {
	[self performMessageWrite:message withTimeout:-1 context:&_AFHTTPConnectionWriteResponseContext];
}

- (void)readResponse {
	[self performRead:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadResponseContext];
}

- (void)downloadResponse:(NSURL *)location {
	NSParameterAssert([location isFileURL]);
	
	AFHTTPMessagePacket *messagePacket = [[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease];
	[messagePacket downloadBodyToURL:location];
	[super performRead:messagePacket withTimeout:-1 context:&_AFHTTPConnectionReadResponseContext];
}

#pragma mark -

@end

@implementation AFHTTPConnection (AFAdditions)

- (void)performDownload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation {
	NSParameterAssert([fileLocation isFileURL]);
	
	CFHTTPMessageRef request = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	[self performMessageWrite:request withTimeout:-1 context:&_AFHTTPConnectionWriteRequestContext];
	
	[self downloadResponse:fileLocation];
}

- (BOOL)performUpload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation error:(NSError **)errorRef {
	NSParameterAssert([fileLocation isFileURL]);
	
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileLocation path] error:errorRef];
	if (fileAttributes == nil) return NO;
	
	CFHTTPMessageRef request = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[fileAttributes objectForKey:NSFileSize] stringValue]);
	[self performWrite:[self _packetForMessage:request] withTimeout:-1 context:&_AFHTTPConnectionWriteRequestContext];
	
	AFPacketWriteFromReadStream *streamPacket = [[[AFPacketWriteFromReadStream alloc] initWithContext:NULL timeout:-1 readStream:[NSInputStream inputStreamWithURL:fileLocation] numberOfBytesToWrite:-1] autorelease];
	[self performWrite:streamPacket withTimeout:-1 context:&_AFHTTPConnectionWriteRequestContext];
	
	[self readResponse];
	
	return YES;
}

@end

@implementation AFHTTPConnection (_Delegate)

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data context:(void *)context {
	if (context == &_AFHTTPConnectionWriteRequestContext) {
		// nop
	} else if (context == &_AFHTTPConnectionWriteResponseContext) {
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

@implementation AFHTTPConnection (Private)

- (CFHTTPMessageRef)_requestForMethod:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body {
	NSURL *endpoint = [self peer];
	NSURL *resourcePath = [NSURL URLWithString:([resource isEmpty] ? @"/" : resource) relativeToURL:endpoint];
	
	CFHTTPMessageRef request = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)HTTPMethod, (CFURLRef)resourcePath, kCFHTTPVersion1_1)) autorelease];
	
	for (NSString *currentKey in headers) {
		NSString *currentValue = [headers objectForKey:currentKey];
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)currentKey, (CFStringRef)currentValue);
	}
	CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageHostHeader, (CFStringRef)[endpoint absoluteString]);
	
	CFHTTPMessageSetBody(request, (CFDataRef)body);
	
	[self _prepareMessage:request];
	
	return request;
}

- (void)_prepareMessage:(CFHTTPMessageRef)message {
	if ([NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease] == nil) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[NSNumber numberWithUnsignedInteger:[[NSMakeCollectable(CFHTTPMessageCopyBody(message)) autorelease] length]] stringValue]);
	}
	
	for (NSString *currentConnectionHeader in [self.messageHeaders allKeys]) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)currentConnectionHeader, (CFStringRef)[self.messageHeaders objectForKey:currentConnectionHeader]);
	}
}
												 
@end
