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
#import "AFPacketQueue.h"
#import "AFHTTPMessage.h"
#import "AFHTTPTransaction.h"
#import "AFHTTPMessagePacket.h"
#import "AFPacketWrite.h"
#import "AFPacketWriteFromReadStream.h"
#import "NSURLRequest+AFHTTPAdditions.h"

NSSTRING_CONTEXT(_AFHTTPConnectionCurrentTransactionObservationContext);

NSSTRING_CONTEXT(_AFHTTPConnectionWriteRequestContext);
NSSTRING_CONTEXT(_AFHTTPConnectionWriteResponseContext);

NSSTRING_CONTEXT(_AFHTTPConnectionReadRequestContext);
NSSTRING_CONTEXT(_AFHTTPConnectionReadPartialResponseContext);
NSSTRING_CONTEXT(_AFHTTPConnectionReadResponseContext);

NS_INLINE AFPacket *_AFHTTPConnectionPacketForMessage(CFHTTPMessageRef message) {
	NSData *messageData = [NSMakeCollectable(CFHTTPMessageCopySerializedMessage(message)) autorelease];
	return [[[AFPacketWrite alloc] initWithContext:NULL timeout:-1 data:messageData] autorelease];
}

@interface AFHTTPConnection ()
@property (readwrite, retain) NSMutableDictionary *messageHeaders;
@property (retain) AFPacketQueue *transactionQueue;
@property (readonly) AFHTTPTransaction *currentTransaction;
@end

@interface AFHTTPConnection (Private)
- (CFHTTPMessageRef)_requestForMethod:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body;
- (void)_enqueueTransactionWithRequestPackets:(NSArray *)requestPackets responsePackets:(NSArray *)responsePackets;
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
		
		if ([newPacket responsePackets] != nil) for (id <AFPacketReading> currentPacket in [newPacket responsePackets]) {
			void *context = &_AFHTTPConnectionReadPartialResponseContext;
			if (currentPacket == [[newPacket responsePackets] lastObject]) context = &_AFHTTPConnectionReadResponseContext;
			[self performRead:currentPacket withTimeout:-1 context:context];
		} else {
			[self readResponse];
		}
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (AFHTTPTransaction *)currentTransaction {
	return self.transactionQueue.currentPacket;
}

- (void)preprocessRequest:(CFHTTPMessageRef)request {
	if ([NSMakeCollectable(CFHTTPMessageCopyHeaderFieldValue(request, (CFStringRef)AFHTTPMessageContentLengthHeader)) autorelease] == nil) {
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[NSNumber numberWithUnsignedInteger:[[NSMakeCollectable(CFHTTPMessageCopyBody(request)) autorelease] length]] stringValue]);
	}
	
	for (NSString *currentConnectionHeader in [self.messageHeaders allKeys]) {
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)currentConnectionHeader, (CFStringRef)[self.messageHeaders objectForKey:currentConnectionHeader]);
	}
}

#pragma mark -
#pragma mark Transaction Messaging

- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body {
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:body];
	[self _enqueueTransactionWithRequestPackets:[NSArray arrayWithObject:_AFHTTPConnectionPacketForMessage(requestMessage)] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]]];
}

- (BOOL)performRequest:(NSURLRequest *)request error:(NSError **)errorRef {
	NSParameterAssert([request HTTPBodyStream] == nil);
	
	NSURL *fileLocation = [request HTTPBodyFile];
	if (fileLocation != nil) {
		NSParameterAssert([fileLocation isFileURL]);
		
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileLocation path] error:errorRef];
		if (fileAttributes == nil) return NO;
		
		CFHTTPMessageRef requestMessage = [self _requestForMethod:[request HTTPMethod] onResource:[[request URL] path] withHeaders:[request allHTTPHeaderFields] withBody:nil];
		CFHTTPMessageSetHeaderFieldValue(requestMessage, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[fileAttributes objectForKey:NSFileSize] stringValue]);
		
		AFPacketWriteFromReadStream *streamPacket = [[[AFPacketWriteFromReadStream alloc] initWithContext:NULL timeout:-1 readStream:[NSInputStream inputStreamWithURL:fileLocation] numberOfBytesToWrite:-1] autorelease];
		
		[self _enqueueTransactionWithRequestPackets:[NSArray arrayWithObjects:_AFHTTPConnectionPacketForMessage(requestMessage), streamPacket, nil] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]]];
		return YES;
	}
	
	CFHTTPMessageRef requestMessage = (CFHTTPMessageRef)[NSMakeCollectable(AFHTTPMessageCreateForRequest(request)) autorelease];
	[self preprocessRequest:requestMessage];
	[self _enqueueTransactionWithRequestPackets:[NSArray arrayWithObject:_AFHTTPConnectionPacketForMessage(requestMessage)] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]]];
	
	return YES;
}

#pragma mark -
#pragma mark Raw Messaging

- (void)performRequestMessage:(CFHTTPMessageRef)message {
	[self preprocessRequest:message];
	[self performWrite:_AFHTTPConnectionPacketForMessage(message) withTimeout:-1 context:&_AFHTTPConnectionWriteRequestContext];
}

- (void)readRequest {
	[self performRead:[[[AFHTTPMessagePacket alloc] initForRequest:YES] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadRequestContext];
}

- (void)downloadRequest:(NSURL *)location {
	NSParameterAssert([location isFileURL]);
	
	[self doesNotRecognizeSelector:_cmd];
}

- (void)performResponseMessage:(CFHTTPMessageRef)message {
	[self performWrite:_AFHTTPConnectionPacketForMessage(message) withTimeout:-1 context:&_AFHTTPConnectionWriteResponseContext];
}

- (void)readResponse {
	[self performRead:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease] withTimeout:-1 context:&_AFHTTPConnectionReadResponseContext];
}

- (void)downloadResponse:(NSURL *)location {
	NSParameterAssert([location isFileURL]);
	
	AFHTTPMessagePacket *messagePacket = [[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease];
	[messagePacket downloadBodyToURL:location];
	[self performRead:messagePacket withTimeout:-1 context:&_AFHTTPConnectionReadResponseContext];
}

@end

#pragma mark -

@implementation AFHTTPConnection (AFAdditions)

- (void)performDownload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation {
	NSParameterAssert([fileLocation isFileURL]);
	
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	
	AFHTTPMessagePacket *messagePacket = [[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease];
	[messagePacket downloadBodyToURL:fileLocation];
	
	[self _enqueueTransactionWithRequestPackets:[NSArray arrayWithObject:_AFHTTPConnectionPacketForMessage(requestMessage)] responsePackets:[NSArray arrayWithObject:messagePacket]];
}

- (BOOL)performUpload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation error:(NSError **)errorRef {
	NSParameterAssert([fileLocation isFileURL]);
	
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileLocation path] error:errorRef];
	if (fileAttributes == nil) return NO;
	
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	CFHTTPMessageSetHeaderFieldValue(requestMessage, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[fileAttributes objectForKey:NSFileSize] stringValue]);
	
	AFPacket *headersPacket = _AFHTTPConnectionPacketForMessage(requestMessage);
	AFPacketWriteFromReadStream *bodyPacket = [[[AFPacketWriteFromReadStream alloc] initWithContext:NULL timeout:-1 readStream:[NSInputStream inputStreamWithURL:fileLocation] numberOfBytesToWrite:[[fileAttributes objectForKey:NSFileSize] unsignedIntegerValue]] autorelease];
	
	[self _enqueueTransactionWithRequestPackets:[NSArray arrayWithObjects:headersPacket, bodyPacket, nil] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]]];
	
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
	if (context == &_AFHTTPConnectionReadRequestContext) {
		if ([self.delegate respondsToSelector:@selector(connection:didReceiveRequest:)])
			[self.delegate connection:self didReceiveRequest:(CFHTTPMessageRef)data];
	} else if (context == &_AFHTTPConnectionReadPartialResponseContext) {
		// nop
	} else if (context == &_AFHTTPConnectionReadResponseContext) {
		if ([self.delegate respondsToSelector:@selector(connection:didReceiveResponse:)])
			[self.delegate connection:self didReceiveResponse:(CFHTTPMessageRef)data];
		
		[self.transactionQueue dequeued];
		[self.transactionQueue tryDequeue];
	} else {
		if ([self.delegate respondsToSelector:_cmd])
			[self.delegate layer:self didRead:data context:context];
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
	
	[self preprocessRequest:request];
	
	return request;
}

- (void)_enqueueTransactionWithRequestPackets:(NSArray *)requestPackets responsePackets:(NSArray *)responsePackets {
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:requestPackets responsePackets:responsePackets] autorelease];
	[self.transactionQueue enqueuePacket:transaction];
	[self.transactionQueue tryDequeue];
}
												 
@end
