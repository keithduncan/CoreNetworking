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
#import "AFNetworkPacketQueue.h"
#import "AFNetworkPacketWriteFromReadStream.h"
#import "AFHTTPMessage.h"
#import "AFHTTPMessagePacket.h"
#import "AFHTTPTransaction.h"

#import "NSURLRequest+AFNetworkAdditions.h"

#import "AFNetwork-Constants.h"
#import "AFNetwork-Macros.h"

AFNETWORK_NSSTRING_CONTEXT(_AFHTTPClientCurrentTransactionObservationContext);

AFNETWORK_NSSTRING_CONTEXT(_AFHTTPClientWritePartialRequestContext);
AFNETWORK_NSSTRING_CONTEXT(_AFHTTPClientWriteRequestContext);

AFNETWORK_NSSTRING_CONTEXT(_AFHTTPClientReadPartialResponseContext); // All packets contribute to the transfer notifications
AFNETWORK_NSSTRING_CONTEXT(_AFHTTPClientReadResponseContext); // The last packet's buffer is returned in the didRead: notification

@interface AFHTTPClient ()
@property (retain, nonatomic) AFNetworkPacketQueue *transactionQueue;
@property (readonly, nonatomic) AFHTTPTransaction *currentTransaction;
@end

@interface AFHTTPClient (AFNetworkPrivate)
- (BOOL)_shouldStartTLS;

- (CFHTTPMessageRef)_requestForMethod:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body;

- (AFHTTPMessagePacket *)_readResponsePacketForTransaction:(AFHTTPTransaction *)transaction;

- (void)_transaction:(AFHTTPTransaction *)transaction disableIdleTimeoutTimerForPacketsKey:(NSString *)packetsKey;
- (void)_transaction:(AFHTTPTransaction *)transaction enableIdleTimeoutTimerForPacketsKey:(NSString *)packetsKey;

- (void)_transaction:(AFHTTPTransaction *)transaction packetsKey:(NSString *)packetsKey didPartial:(NSUInteger)currentPartial delegateSelector:(SEL)delegateSelector;
@end

@implementation AFHTTPClient

@dynamic delegate;
@synthesize userAgent=_userAgent;
@synthesize transactionQueue=_transactionQueue;

+ (void)initialize {
	[super initialize];
	if (self != [AFHTTPClient class]) return;
	
	[self setUserAgent:AFHTTPAgentString()];
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
		[_AFHTTPClientUserAgent autorelease];
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
	
	[_transactionQueue removeObserver:self forKeyPath:@"currentPacket"];
	[_transactionQueue release];
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context == &_AFHTTPClientCurrentTransactionObservationContext) {
		AFHTTPTransaction *newTransaction = [change objectForKey:NSKeyValueChangeNewKey];
		if (newTransaction == nil || [newTransaction isEqual:[NSNull null]]) {
			return;
		}
		
		NSArray *requestPackets = newTransaction.requestPackets;
		for (id <AFNetworkPacketWriting> currentPacket in requestPackets) {
			void *packetContext = &_AFHTTPClientWritePartialRequestContext;
			if (currentPacket == [[newTransaction requestPackets] lastObject]) {
				packetContext = &_AFHTTPClientWriteRequestContext;
			}
			
			[self performWrite:currentPacket withTimeout:-1 context:packetContext];
		}
		
		NSArray *responsePackets = newTransaction.responsePackets;
		for (id <AFNetworkPacketReading> currentPacket in responsePackets) {
			void *packetContext = &_AFHTTPClientReadPartialResponseContext;
			if (currentPacket == [[newTransaction responsePackets] lastObject]) {
				packetContext = &_AFHTTPClientReadResponseContext;
			}
			
			[self performRead:currentPacket withTimeout:-1 context:packetContext];
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (AFHTTPTransaction *)currentTransaction {
	return self.transactionQueue.currentPacket;
}

- (void)prepareMessageForTransport:(CFHTTPMessageRef)message {
	[super prepareMessageForTransport:message];
	
	if (!CFHTTPMessageIsRequest(message)) {
		return;
	}
	
	NSString *agent = self.userAgent;
	if (agent != nil) {
		CFHTTPMessageSetHeaderFieldValue(message, (CFStringRef)AFHTTPMessageUserAgentHeader, (CFStringRef)agent);
	}
}

- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body context:(void *)context {
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:body];
	
	AFNetworkPacket *requestPacket = AFHTTPConnectionPacketForMessage(requestMessage);
	
	NSArray *requestPackets = [NSArray arrayWithObjects:
							   requestPacket,
							   nil];
	
	AFHTTPMessagePacket *responsePacket = [self _readResponsePacketForTransaction:nil];
	
	NSArray *responsePackets = [NSArray arrayWithObjects:
								responsePacket,
								nil];
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:requestPackets responsePackets:responsePackets context:context] autorelease];
	[self enqueueTransaction:transaction];
}

- (void)performRequest:(NSURLRequest *)request context:(void *)context {
	NSParameterAssert([request HTTPBodyStream] == nil);
	
	NSURL *fileLocation = [request HTTPBodyFile];
	if (fileLocation != nil) {
		NSParameterAssert([fileLocation isFileURL]);
		
		NSNumber *fileSize = nil; NSError *fileSizeError = nil;
		BOOL getFileSize = [fileLocation getResourceValue:&fileSize forKey:NSURLFileSizeKey error:&fileSizeError];
		if (!getFileSize) {
			#warning this needs a better error
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									   fileSizeError, NSUnderlyingErrorKey,
									   nil];
			NSError *streamUploadError = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkErrorUnknown userInfo:errorInfo];
			
			[(id)self.delegate networkLayer:self didReceiveError:streamUploadError];
			return;
		}
		
		CFHTTPMessageRef requestMessage = [self _requestForMethod:[request HTTPMethod] onResource:[[request URL] path] withHeaders:[request allHTTPHeaderFields] withBody:nil];
		CFHTTPMessageSetHeaderFieldValue(requestMessage, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[fileSize stringValue]);
		AFNetworkPacket *requestPacket = AFHTTPConnectionPacketForMessage(requestMessage);
		
		AFNetworkPacketWriteFromReadStream *streamPacket = [[[AFNetworkPacketWriteFromReadStream alloc] initWithTotalBytesToWrite:-1 readStream:[NSInputStream inputStreamWithURL:fileLocation]] autorelease];
		
		NSArray *requestPackets = [NSArray arrayWithObjects:
								   requestPacket,
								   streamPacket,
								   nil];
		
		AFHTTPMessagePacket *responsePacket = [self _readResponsePacketForTransaction:nil];
		
		NSArray *responsePackets = [NSArray arrayWithObjects:
									responsePacket,
									nil];
		
		AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:requestPackets responsePackets:responsePackets context:context] autorelease];
		[self enqueueTransaction:transaction];
		return;
	}
	
	CFHTTPMessageRef requestMessage = (CFHTTPMessageRef)[NSMakeCollectable(AFHTTPMessageCreateForRequest(request)) autorelease];
	[self prepareMessageForTransport:requestMessage];
	
	AFNetworkPacket *requestPacket = AFHTTPConnectionPacketForMessage(requestMessage);
	
	NSArray *requestPackets = [NSArray arrayWithObjects:
							   requestPacket,
							   nil];
	
	AFHTTPMessagePacket *responsePacket = [self _readResponsePacketForTransaction:nil];
	
	NSArray *responsePackets = [NSArray arrayWithObjects:
								responsePacket,
								nil];
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:requestPackets responsePackets:responsePackets context:context] autorelease];
	[self enqueueTransaction:transaction];
}

- (void)performDownload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation context:(void *)context {
	NSParameterAssert([fileLocation isFileURL]);
	
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	
	AFNetworkPacket *requestPacket = AFHTTPConnectionPacketForMessage(requestMessage);
	
	NSArray *requestPackets = [NSArray arrayWithObjects:
							   requestPacket,
							   nil];
	
	AFHTTPMessagePacket *responsePacket = [self _readResponsePacketForTransaction:nil];
	[responsePacket setBodyStorage:fileLocation];
	
	NSArray *responsePackets = [NSArray arrayWithObjects:
								responsePacket,
								nil];
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:requestPackets responsePackets:responsePackets context:context] autorelease];
	[self enqueueTransaction:transaction];
}

- (BOOL)performUpload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation context:(void *)context error:(NSError **)errorRef {
	NSParameterAssert([fileLocation isFileURL]);
	
	NSNumber *fileSize = nil;
	BOOL getFileSize = [fileLocation getResourceValue:&fileSize forKey:NSURLFileSizeKey error:errorRef];
	if (!getFileSize) {
		return NO;
	}
	
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	CFHTTPMessageSetHeaderFieldValue(requestMessage, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[fileSize stringValue]);
	
	#warning we should be prepared to remove this header if we receive a 417 expectation failed response
	CFHTTPMessageSetHeaderFieldValue(requestMessage, (CFStringRef)AFHTTPMessageExpectHeader, (CFStringRef)@"100-Continue");
	
	AFNetworkPacket *headersPacket = AFHTTPConnectionPacketForMessage(requestMessage);
	AFNetworkPacketWriteFromReadStream *bodyPacket = [[[AFNetworkPacketWriteFromReadStream alloc] initWithTotalBytesToWrite:[fileSize unsignedIntegerValue] readStream:[NSInputStream inputStreamWithURL:fileLocation]] autorelease];
	
	NSArray *requestPackets = [NSArray arrayWithObjects:
							   headersPacket,
							   bodyPacket,
							   nil];
	
	AFHTTPMessagePacket *responsePacket = [self _readResponsePacketForTransaction:nil];
	
	NSArray *responsePackets = [NSArray arrayWithObjects:
								responsePacket,
								nil];
	
	AFHTTPTransaction *transaction = [[[AFHTTPTransaction alloc] initWithRequestPackets:requestPackets responsePackets:responsePackets context:context] autorelease];
	[self enqueueTransaction:transaction];
	
	return YES;
}

- (void)enqueueTransaction:(AFHTTPTransaction *)transaction {
	/*
		Note
		
		we have to do this for all transactions so that external transactions have their response packet idle timers disabled too
	 */
	[self _transaction:transaction disableIdleTimeoutTimerForPacketsKey:AFHTTPTransactionResponsePacketsKey];
	
	[self.transactionQueue enqueuePacket:transaction];
	[self.transactionQueue tryDequeue];
}

- (void)networkLayerDidOpen:(id <AFNetworkConnectionLayer>)layer {
	if ([self _shouldStartTLS]) {
		/*
			Note
			
			this option is documented in Technical Note TN2287 <http://developer.apple.com/library/ios/#technotes/tn2287/_index.html>
			
			it specifies a maximum of TLSv1.2 and a minimum of SSLv3
		 */
		NSDictionary *securityOptions = [NSDictionary dictionaryWithObjectsAndKeys:
										 (id)@"kCFStreamSocketSecurityLevelTLSv1_2SSLv3", (id)kCFStreamSSLLevel,
										 nil];
		
		NSError *TLSError = nil;
		BOOL secureNegotiation = [self startTLS:securityOptions error:&TLSError];
		if (!secureNegotiation) {
			[(id)self.delegate networkLayer:self didReceiveError:TLSError];
			
			[self close];
			return;
		}
	}
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidOpen:)]) {
		[(id)self.delegate networkLayerDidOpen:self];
	}
}

- (void)networkLayerDidClose:(id <AFNetworkConnectionLayer>)layer {
	if (self.transactionQueue.count > 0) {
		[self.transactionQueue emptyQueue];
		
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   NSLocalizedStringFromTableInBundle(@"Server unexpectedly dropped the connection", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFHTTPClient network closed with inflight transaction error description"), NSLocalizedDescriptionKey,
								   NSLocalizedStringFromTableInBundle(@"This sometimes occurs when the server is busy. Please wait a few minutes and try again.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFHTTPClient network closed with inflight transaction error recovery suggestion"), NSLocalizedRecoverySuggestionErrorKey,
								   nil];
		NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkErrorUnknown userInfo:errorInfo];
		
		[self.delegate networkLayer:self didReceiveError:error];
	}
	
	struct objc_super target = {
		.receiver = self,
		.super_class = [self superclass],
	};
	((void (*)(struct objc_super *, SEL, id <AFNetworkConnectionLayer>))objc_msgSendSuper)(&target, @selector(networkLayerDidClose:), layer);
}

- (void)networkTransport:(AFNetworkTransport *)transport didWritePartialDataOfLength:(NSInteger)partialLength totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite context:(void *)context {
	if (![self.delegate respondsToSelector:_cmd]) {
		return;
	}
	
	if (context == &_AFHTTPClientWritePartialRequestContext || context == &_AFHTTPClientWriteRequestContext) {
		[self _transaction:self.currentTransaction packetsKey:AFHTTPTransactionRequestPacketsKey didPartial:partialLength delegateSelector:_cmd];
	}
	else {
		[(id)self.delegate networkTransport:transport didWritePartialDataOfLength:partialLength totalBytesWritten:totalBytesWritten totalBytesExpectedToWrite:totalBytesExpectedToWrite context:context];
	}
}

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didWrite:(id)packet context:(void *)context {
	if (context == &_AFHTTPClientWritePartialRequestContext) {
		//nop
	}
	else if (context == &_AFHTTPClientWriteRequestContext) {
		AFHTTPTransaction *currentTransaction = self.currentTransaction;
		currentTransaction.finishedRequestPackets = YES;
		
		[self _transaction:self.currentTransaction enableIdleTimeoutTimerForPacketsKey:AFHTTPTransactionResponsePacketsKey];
	}
	else {
		[super networkLayer:layer didWrite:packet context:context];
	}
}

- (void)networkTransport:(AFNetworkTransport *)transport didReadPartialDataOfLength:(NSInteger)partialBytes totalBytesRead:(NSInteger)totalBytesRead totalBytesExpectedToRead:(NSInteger)totalLength context:(void *)context {
	if (![self.delegate respondsToSelector:_cmd]) {
		return;
	}
	
	if (context == &_AFHTTPClientReadPartialResponseContext || context == &_AFHTTPClientReadResponseContext) {
		[self _transaction:self.currentTransaction packetsKey:AFHTTPTransactionResponsePacketsKey didPartial:partialBytes delegateSelector:_cmd];
	}
	else {
		[(id)self.delegate networkTransport:transport didReadPartialDataOfLength:partialBytes totalBytesRead:totalBytesRead totalBytesExpectedToRead:totalLength context:context];
	}
}

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didRead:(id)packet context:(void *)context {
	if (context == &_AFHTTPClientReadPartialResponseContext) {
		// nop
	}
	else if (context == &_AFHTTPClientReadResponseContext) {
		AFHTTPTransaction *currentTransaction = [[self.currentTransaction retain] autorelease];
		CFHTTPMessageRef response = (CFHTTPMessageRef)[(AFHTTPMessagePacket *)packet buffer];
		
		// WARNING: we should implement a peak behaviour so that we read the header outselves first and if it's a code we handle automatically (100, 101, 301, 302, 304, 307, 417, 426) read it without touching the requestPackets array, if it isn't funnel the data we've already read into the packets to handle
		// WARNING: the following assumes a default read packet, this isn't a safe assumption and will be fixed with the peak behaviour noted above
		// WARNING: the following check is implemented in the superclass too, we should either harmonise the handling of common codes, or move them all into AFHTTPClient, so that AFHTTPConnection is raw messaging only
		
		CFIndex responseStatusCode = CFHTTPMessageGetResponseStatusCode(response);
		if (responseStatusCode >= AFHTTPStatusCodeContinue && responseStatusCode <= 199) {
			AFHTTPMessagePacket *responsePacket = [self _readResponsePacketForTransaction:currentTransaction];
			[self performRead:responsePacket withTimeout:-1 context:&_AFHTTPClientReadResponseContext];
			return;
		}
		
		currentTransaction.finishedResponsePackets = YES;
		
		// WARNING: should we wait until both the request is written and response read before informing the delegate?
		
		/*
			Note
			
			dequeue before calling the delegate, if they close the connection we don't want to complain about an outstanding transaction
		 */
		[self.transactionQueue dequeued];
		
		[self.delegate networkConnection:self didReceiveResponse:response context:currentTransaction.context];
		
		[self.transactionQueue tryDequeue];
	}
	else {
		[super networkLayer:layer didRead:packet context:context];
	}
}

@end

@implementation AFHTTPClient (AFNetworkPrivate)

- (BOOL)_shouldStartTLS {
	if (CFGetTypeID([(id)self.lowerLayer peer]) == CFHostGetTypeID()) {
		return _shouldStartTLS;
	}
	
	@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%s, cannot determine whether to start TLS automatically", __PRETTY_FUNCTION__] userInfo:nil];
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
	
	[self prepareMessageForTransport:request];
	
	return request;
}

- (AFHTTPMessagePacket *)_readResponsePacketForTransaction:(AFHTTPTransaction *)transaction {
	AFHTTPMessagePacket *responsePacket = [[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease];
	if (transaction != nil && !transaction.finishedRequestPackets) {
		[responsePacket disableIdleTimeout];
	}
	return responsePacket;
}

- (void)_transaction:(AFHTTPTransaction *)transaction disableIdleTimeoutTimerForPacketsKey:(NSString *)packetsKey {
	[[transaction valueForKey:packetsKey] makeObjectsPerformSelector:@selector(disableIdleTimeout)];
}

- (void)_transaction:(AFHTTPTransaction *)transaction enableIdleTimeoutTimerForPacketsKey:(NSString *)packetsKey {
	[[transaction valueForKey:packetsKey] makeObjectsPerformSelector:@selector(enableIdleTimeout)];
}

- (void)_transaction:(AFHTTPTransaction *)transaction packetsKey:(NSString *)packetsKey didPartial:(NSUInteger)currentPartial delegateSelector:(SEL)delegateSelector {
	AFHTTPTransaction *currentTransaction = self.currentTransaction;
	
	NSArray *packets = [currentTransaction valueForKey:packetsKey];
	NSUInteger currentTransactionPartial = 0, currentTransactionTotal = 0;
	for (AFNetworkPacket *currentPacket in packets) {
		NSInteger currentPacketPartial = 0, currentPacketTotal = 0;
		float percentage = [currentPacket currentProgressWithBytesDone:&currentPacketPartial bytesTotal:&currentPacketTotal];
		if (isnan(percentage)) {
			continue;
		}
		
		currentTransactionPartial += currentPacketPartial;
		currentTransactionTotal += currentPacketTotal;
	}
	
	void *context = currentTransaction.context;
	
	((void (*)(id, SEL, id, NSUInteger, NSUInteger, NSUInteger, void *))objc_msgSend)(self.delegate, delegateSelector, self, currentPartial, currentTransactionPartial, currentTransactionTotal, context);
}

@end
