//
//  AFHTTPClient.m
//  Amber
//
//  Created by Keith Duncan on 03/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPClient.h"

#import <objc/message.h>

#import "AFNetworkTransport.h"
#import "AFNetworkConstants.h"
#import "AFHTTPMessage.h"
#import "AFHTTPMessagePacket.h"
#import "AFNetworkPacketQueue.h"
#import "AFHTTPTransaction.h"
#import "AFNetworkPacketWriteFromReadStream.h"
#import "NSURLRequest+AFNetworkAdditions.h"

#import "AFNetworkMacros.h"

AFNETWORK_NSSTRING_CONTEXT(_AFHTTPClientCurrentTransactionObservationContext);

AFNETWORK_NSSTRING_CONTEXT(_AFHTTPClientWritePartialRequestContext);
AFNETWORK_NSSTRING_CONTEXT(_AFHTTPClientWriteRequestContext);

AFNETWORK_NSSTRING_CONTEXT(_AFHTTPClientReadPartialResponseContext);
AFNETWORK_NSSTRING_CONTEXT(_AFHTTPClientReadResponseContext);

@interface AFHTTPClient ()
@property (retain) AFNetworkPacketQueue *transactionQueue;
@property (readonly) AFHTTPTransaction *currentTransaction;
@end

@interface AFHTTPClient (Private)
- (BOOL)_shouldStartTLS;
- (CFHTTPMessageRef)_requestForMethod:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body;
- (void)_enqueueTransaction:(AFHTTPTransaction *)transaction;
- (void)_partialCurrentTransaction:(NSArray *)packets selector:(SEL)selector;
@end

@implementation AFHTTPClient

@dynamic delegate;
@synthesize userAgent=_userAgent;
@synthesize authentication=_authentication, authenticationCredentials=_authenticationCredentials;
@synthesize transactionQueue=_transactionQueue;

static NSString *_AFHTTPConnectionUserAgentFromBundle(NSBundle *bundle) {
	if (bundle == nil) return nil;
	return [NSString stringWithFormat:@"%@/%@", [[bundle objectForInfoDictionaryKey:(id)@"CFBundleDisplayName"] stringByReplacingOccurrencesOfString:@" " withString:@"-"], [[bundle objectForInfoDictionaryKey:(id)kCFBundleVersionKey] stringByReplacingOccurrencesOfString:@" " withString:@"-"], nil];
}

+ (void)initialize {
	NSMutableArray *components = [NSMutableArray array];
	[components addObjectsFromArray:[NSArray arrayWithObjects:_AFHTTPConnectionUserAgentFromBundle([NSBundle mainBundle]), nil]];
	[components addObjectsFromArray:[NSArray arrayWithObjects:_AFHTTPConnectionUserAgentFromBundle([NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier]), nil]];
	[self setUserAgent:([components count] > 0 ? [components componentsJoinedByString:@" "] : nil)];
}

static NSString *_AFHTTPClientUserAgent = nil;

+ (NSString *)userAgent {
	NSString *agent = nil;
	@synchronized ([AFHTTPClient class]) {
		agent = [[_AFHTTPClientUserAgent retain] autorelease];
	}
	return agent;
}

+ (void)setUserAgent:(NSString *)userAgent {
	@synchronized ([AFHTTPClient class]) {
		[_AFHTTPClientUserAgent release];
		_AFHTTPClientUserAgent = [userAgent copy];
	}
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_userAgent = [[AFHTTPClient userAgent] copy];
	
	_transactionQueue = [[AFNetworkPacketQueue alloc] init];
	[_transactionQueue addObserver:self forKeyPath:@"currentPacket" options:NSKeyValueObservingOptionNew context:&_AFHTTPClientCurrentTransactionObservationContext];
	
	return self;
}

- (id)initWithURL:(NSURL *)endpoint {
	self = (id)[super initWithURL:endpoint];
	if (self == nil) return nil;
	
	_shouldStartTLS = ([AFNetworkSchemeHTTPS compare:[endpoint scheme] options:NSCaseInsensitiveSearch] == NSOrderedSame);
	
	return self;
}

- (void)dealloc {
	[_userAgent release];
	
	if (_authentication != NULL) CFRelease(_authentication);
	[_authenticationCredentials release];
	
	[_transactionQueue removeObserver:self forKeyPath:@"currentPacket"];
	[_transactionQueue release];
	
	[super dealloc];
}

- (void)finalize {
	if (_authentication != NULL) CFRelease(_authentication);
	
	[super finalize];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &_AFHTTPClientCurrentTransactionObservationContext) {
		AFHTTPTransaction *newPacket = [change objectForKey:NSKeyValueChangeNewKey];
		if (newPacket == nil || [newPacket isEqual:[NSNull null]]) return;
		
		for (id <AFNetworkPacketWriting> currentPacket in [newPacket requestPackets]) {
			void *context = &_AFHTTPClientWritePartialRequestContext;
			if (currentPacket == [[newPacket requestPackets] lastObject]) context = &_AFHTTPClientWriteRequestContext;
			[self performWrite:currentPacket withTimeout:-1 context:context];
		}
		
		if ([newPacket responsePackets] != nil) for (id <AFNetworkPacketReading> currentPacket in [newPacket responsePackets]) {
			void *context = &_AFHTTPClientReadPartialResponseContext;
			if (currentPacket == [[newPacket responsePackets] lastObject]) context = &_AFHTTPClientReadResponseContext;
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
	NSString *agent = [self userAgent];
	if (agent != nil) CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageUserAgentHeader, (CFStringRef)agent);
	
	if (self.authentication != NULL) {
		CFStreamError error = {0};
		
		Boolean authenticated = NO;
		authenticated = CFHTTPMessageApplyCredentialDictionary(request, self.authentication, (CFDictionaryRef)self.authenticationCredentials, &error);
#pragma unused (authenticated)
	}
	
	[super preprocessRequest:request];
}

- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body context:(void *)context {
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:body];
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:[NSArray arrayWithObject:AFHTTPConnectionPacketForMessage(requestMessage)] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]] context:context] autorelease];
	[self _enqueueTransaction:transaction];
}

- (void)performRequest:(NSURLRequest *)request context:(void *)context {
	NSParameterAssert([request HTTPBodyStream] == nil);
	
	NSURL *fileLocation = [request HTTPBodyFile];
	if (fileLocation != nil) {
		NSParameterAssert([fileLocation isFileURL]);
		
		NSError *fileAttributesError = nil;
		NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileLocation path] error:&fileAttributesError];
		if (fileAttributes == nil) {
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									   fileAttributesError, NSUnderlyingErrorKey,
									   nil];
			NSError *streamUploadError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:0 userInfo:errorInfo];
			
			[(id)[self delegate] networkLayer:self didReceiveError:streamUploadError];
			return;
		}
		
		CFHTTPMessageRef requestMessage = [self _requestForMethod:[request HTTPMethod] onResource:[[request URL] path] withHeaders:[request allHTTPHeaderFields] withBody:nil];
		CFHTTPMessageSetHeaderFieldValue(requestMessage, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[fileAttributes objectForKey:NSFileSize] stringValue]);
		
		AFNetworkPacketWriteFromReadStream *streamPacket = [[[AFNetworkPacketWriteFromReadStream alloc] initWithReadStream:[NSInputStream inputStreamWithURL:fileLocation] totalBytesToWrite:-1] autorelease];
		
		AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:[NSArray arrayWithObjects:AFHTTPConnectionPacketForMessage(requestMessage), streamPacket, nil] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]] context:context] autorelease];
		[self _enqueueTransaction:transaction];
		
		return;
	}
	
	CFHTTPMessageRef requestMessage = (CFHTTPMessageRef)[NSMakeCollectable(AFHTTPMessageCreateForRequest(request)) autorelease];
	[self preprocessRequest:requestMessage];
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:[NSArray arrayWithObject:AFHTTPConnectionPacketForMessage(requestMessage)] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]] context:context] autorelease];
	[self _enqueueTransaction:transaction];
}

- (void)performDownload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation context:(void *)context {
	NSParameterAssert([fileLocation isFileURL]);
	
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	
	AFHTTPMessagePacket *messagePacket = [[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease];
	[messagePacket setBodyStorage:fileLocation];
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:[NSArray arrayWithObject:AFHTTPConnectionPacketForMessage(requestMessage)] responsePackets:[NSArray arrayWithObject:messagePacket] context:context] autorelease];
	[self _enqueueTransaction:transaction];
}

- (BOOL)performUpload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation context:(void *)context error:(NSError **)errorRef {
	NSParameterAssert([fileLocation isFileURL]);
	
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileLocation path] error:errorRef];
	NSNumber *fileSize = [fileAttributes objectForKey:NSFileSize];
	if (fileAttributes == nil || fileSize == nil) return NO;
	
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	CFHTTPMessageSetHeaderFieldValue(requestMessage, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[fileSize stringValue]);
	
	AFNetworkPacket *headersPacket = AFHTTPConnectionPacketForMessage(requestMessage);
	AFNetworkPacketWriteFromReadStream *bodyPacket = [[[AFNetworkPacketWriteFromReadStream alloc] initWithReadStream:[NSInputStream inputStreamWithURL:fileLocation] totalBytesToWrite:[fileSize unsignedIntegerValue]] autorelease];
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:[NSArray arrayWithObjects:headersPacket, bodyPacket, nil] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]] context:context] autorelease];
	[self _enqueueTransaction:transaction];
	
	return YES;
}

- (void)networkLayerDidOpen:(id <AFNetworkConnectionLayer>)layer {
	if ([self _shouldStartTLS]) {
		NSDictionary *securityOptions = [NSDictionary dictionaryWithObjectsAndKeys:
										 (id)kCFStreamSocketSecurityLevelNegotiatedSSL, (id)kCFStreamSSLLevel,
										 nil];
		
		NSError *TLSError = nil;
		BOOL secureNegotiation = [self startTLS:securityOptions error:&TLSError];
		if (!secureNegotiation) {
			if ([self.delegate respondsToSelector:@selector(networkLayer:didNotStartTLS:)]) {
				[(id)self.delegate networkLayer:self didNotStartTLS:TLSError];
			} else if ([self.delegate respondsToSelector:@selector(networkLayer:didReceiveError:)]) {
				[(id)self.delegate networkLayer:self didReceiveError:TLSError];
			}
			
			[self close];
			return;
		}
	}
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidOpen:)]) {
		[(id)self.delegate networkLayerDidOpen:self];
	}
}

- (void)networkTransport:(AFNetworkTransport *)transport didWritePartialDataOfLength:(NSInteger)partialLength totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite context:(void *)context {
	if (![[self delegate] respondsToSelector:_cmd]) return;
	
	if (context == &_AFHTTPClientWritePartialRequestContext || context == &_AFHTTPClientWriteRequestContext) {
		AFHTTPTransaction *currentTransaction = [self currentTransaction];
		[self _partialCurrentTransaction:[currentTransaction requestPackets] selector:_cmd];
	} else {
		[(id)[self delegate] networkTransport:transport didWritePartialDataOfLength:partialLength totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite context:context];
	}
}

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didWrite:(id)data context:(void *)context {
	if (context == &_AFHTTPClientWritePartialRequestContext) {
		// nop
	} else if (context == &_AFHTTPClientWriteRequestContext) {
		// nop
	} else [super networkLayer:layer didWrite:data context:context];
}

- (void)networkTransport:(AFNetworkTransport *)transport didReadPartialDataOfLength:(NSUInteger)partialLength total:(NSUInteger)totalLength context:(void *)context {
	if (![[self delegate] respondsToSelector:_cmd]) return;
	
	if (context == &_AFHTTPClientReadPartialResponseContext || context == &_AFHTTPClientReadResponseContext) {
		AFHTTPTransaction *currentTransaction = [self currentTransaction];
		[self _partialCurrentTransaction:[currentTransaction responsePackets] selector:_cmd];
	} else {
		[(id)[self delegate] networkTransport:transport didReadPartialDataOfLength:partialLength total:totalLength context:context];
	}
}

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didRead:(id)data context:(void *)context {
	if (context == &_AFHTTPClientReadPartialResponseContext) {
		// nop
	} else if (context == &_AFHTTPClientReadResponseContext) {
		[self.delegate networkConnection:self didReadResponse:(CFHTTPMessageRef)data context:context];
		
		[self.transactionQueue dequeued];
		[self.transactionQueue tryDequeue];
	} else [super networkLayer:layer didRead:data context:context];
}

@end

@implementation AFHTTPClient (Private)

- (BOOL)_shouldStartTLS {
	if (CFGetTypeID([(id)self.lowerLayer peer]) == CFHostGetTypeID()) {
		return _shouldStartTLS;
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"%s, cannot determine wether to start TLS.", __PRETTY_FUNCTION__, nil];
	return NO;
}

- (CFHTTPMessageRef)_requestForMethod:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body {
	NSURL *endpoint = [self peer];
	NSURL *resourcePath = [NSURL URLWithString:([[resource stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0 ? @"/" : resource) relativeToURL:endpoint];
	
	CFHTTPMessageRef request = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)HTTPMethod, (CFURLRef)resourcePath, kCFHTTPVersion1_1)) autorelease];
	
	for (NSString *currentKey in headers) {
		NSString *currentValue = [headers objectForKey:currentKey];
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)currentKey, (CFStringRef)currentValue);
	}
	
	CFHTTPMessageSetBody(request, (CFDataRef)body);
	
	[self preprocessRequest:request];
	
	return request;
}

- (void)_enqueueTransaction:(AFHTTPTransaction *)transaction {
	[self.transactionQueue enqueuePacket:transaction];
	[self.transactionQueue tryDequeue];
}

- (void)_partialCurrentTransaction:(NSArray *)packets selector:(SEL)selector {
	NSUInteger currentTransactionPartial = 0, currentTransactionTotal = 0;
	for (AFNetworkPacket *currentPacket in packets) {
		NSInteger currentPacketPartial = 0, currentPacketTotal = 0;
		float percentage = [currentPacket currentProgressWithBytesDone:&currentPacketPartial bytesTotal:&currentPacketTotal];
		
		if (isnan(percentage)) continue;
		
		currentTransactionPartial += currentPacketPartial;
		currentTransactionTotal += currentPacketTotal;
	}
	
	((void (*)(id, SEL, id, NSUInteger, NSUInteger, void *))objc_msgSend)([self delegate], selector, self, currentTransactionPartial, currentTransactionTotal, [[self currentTransaction] context]);
}

@end
