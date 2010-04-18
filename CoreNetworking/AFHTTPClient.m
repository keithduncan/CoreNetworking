//
//  AFHTTPClient.m
//  Amber
//
//  Created by Keith Duncan on 03/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFHTTPClient.h"

#import "AmberFoundation/AmberFoundation.h"

#import "AFNetworkConstants.h"
#import "AFHTTPMessage.h"
#import "AFHTTPMessagePacket.h"
#import "AFPacketQueue.h"
#import "AFHTTPTransaction.h"
#import "AFPacketWriteFromReadStream.h"
#import "NSURLRequest+AFHTTPAdditions.h"

NSSTRING_CONTEXT(_AFHTTPClientCurrentTransactionObservationContext);

NSSTRING_CONTEXT(_AFHTTPClientWritePartialRequestContext);
NSSTRING_CONTEXT(_AFHTTPClientWriteRequestContext);

NSSTRING_CONTEXT(_AFHTTPClientReadPartialResponseContext);
NSSTRING_CONTEXT(_AFHTTPClientReadResponseContext);

@interface AFHTTPClient ()
@property (retain) AFPacketQueue *transactionQueue;
@property (readonly) AFHTTPTransaction *currentTransaction;
@end

@interface AFHTTPClient (Private)
- (BOOL)_shouldStartTLS;
- (CFHTTPMessageRef)_requestForMethod:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body;
- (void)_enqueueTransactionWithRequestPackets:(NSArray *)requestPackets responsePackets:(NSArray *)responsePackets;
@end

@implementation AFHTTPClient

@synthesize authentication=_authentication, authenticationCredentials=_authenticationCredentials;
@synthesize transactionQueue=_transactionQueue;

static inline NSString *_AFHTTPConnectionUserAgentFromBundle(NSBundle *bundle) {
	return [NSString stringWithFormat:@"%@/%@", [[bundle displayName] stringByReplacingOccurrencesOfString:@" " withString:@"-"], [[bundle displayVersion] stringByReplacingOccurrencesOfString:@" " withString:@"-"], nil];
}

+ (void)initialize {
	NSString *userAgent = [NSString stringWithFormat:@"%@ %@", _AFHTTPConnectionUserAgentFromBundle([NSBundle mainBundle]), _AFHTTPConnectionUserAgentFromBundle([NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier]), nil];
	[self setUserAgent:userAgent];
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
	
	_transactionQueue = [[AFPacketQueue alloc] init];
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
		
		for (id <AFPacketWriting> currentPacket in [newPacket requestPackets]) {
			void *context = &_AFHTTPClientWritePartialRequestContext;
			if (currentPacket == [[newPacket requestPackets] lastObject]) context = &_AFHTTPClientWriteRequestContext;
			[self performWrite:currentPacket withTimeout:-1 context:context];
		}
		
		if ([newPacket responsePackets] != nil) for (id <AFPacketReading> currentPacket in [newPacket responsePackets]) {
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
	NSString *agent = [[self class] userAgent];
	if (agent != nil) CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)AFHTTPMessageUserAgentHeader, (CFStringRef)agent);
	
	if (self.authentication != NULL) {
		CFStreamError error = {0};
		
		Boolean authenticated = NO;
		authenticated = CFHTTPMessageApplyCredentialDictionary(request, self.authentication, (CFDictionaryRef)self.authenticationCredentials, &error);
#pragma unused (authenticated)
	}
	
	[super preprocessRequest:request];
}

- (void)performRequest:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withBody:(NSData *)body {
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:body];
	[self _enqueueTransactionWithRequestPackets:[NSArray arrayWithObject:AFHTTPConnectionPacketForMessage(requestMessage)] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]]];
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
		
		[self _enqueueTransactionWithRequestPackets:[NSArray arrayWithObjects:AFHTTPConnectionPacketForMessage(requestMessage), streamPacket, nil] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]]];
		return YES;
	}
	
	CFHTTPMessageRef requestMessage = (CFHTTPMessageRef)[NSMakeCollectable(AFHTTPMessageCreateForRequest(request)) autorelease];
	[self preprocessRequest:requestMessage];
	[self _enqueueTransactionWithRequestPackets:[NSArray arrayWithObject:AFHTTPConnectionPacketForMessage(requestMessage)] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]]];
	
	return YES;
}

- (void)performDownload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation {
	NSParameterAssert([fileLocation isFileURL]);
	
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	
	AFHTTPMessagePacket *messagePacket = [[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease];
	[messagePacket downloadBodyToURL:fileLocation];
	
	[self _enqueueTransactionWithRequestPackets:[NSArray arrayWithObject:AFHTTPConnectionPacketForMessage(requestMessage)] responsePackets:[NSArray arrayWithObject:messagePacket]];
}

- (BOOL)performUpload:(NSString *)HTTPMethod onResource:(NSString *)resource withHeaders:(NSDictionary *)headers withLocation:(NSURL *)fileLocation error:(NSError **)errorRef {
	NSParameterAssert([fileLocation isFileURL]);
	
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileLocation path] error:errorRef];
	if (fileAttributes == nil) return NO;
	
	CFHTTPMessageRef requestMessage = [self _requestForMethod:HTTPMethod onResource:resource withHeaders:headers withBody:nil];
	CFHTTPMessageSetHeaderFieldValue(requestMessage, (CFStringRef)AFHTTPMessageContentLengthHeader, (CFStringRef)[[fileAttributes objectForKey:NSFileSize] stringValue]);
	
	AFPacket *headersPacket = AFHTTPConnectionPacketForMessage(requestMessage);
	AFPacketWriteFromReadStream *bodyPacket = [[[AFPacketWriteFromReadStream alloc] initWithContext:NULL timeout:-1 readStream:[NSInputStream inputStreamWithURL:fileLocation] numberOfBytesToWrite:[[fileAttributes objectForKey:NSFileSize] unsignedIntegerValue]] autorelease];
	
	[self _enqueueTransactionWithRequestPackets:[NSArray arrayWithObjects:headersPacket, bodyPacket, nil] responsePackets:[NSArray arrayWithObject:[[[AFHTTPMessagePacket alloc] initForRequest:NO] autorelease]]];
	
	return YES;
}

- (void)layerDidOpen:(id <AFConnectionLayer>)layer {
	if ([self _shouldStartTLS]) {
		NSDictionary *securityOptions = [NSDictionary dictionaryWithObjectsAndKeys:
										 (id)kCFStreamSocketSecurityLevelNegotiatedSSL, (id)kCFStreamSSLLevel,
										 nil];
		
		NSError *TLSError = nil;
		BOOL secureNegotiation = [self startTLS:securityOptions error:&TLSError];
		if (secureNegotiation) return;
		
		[self.delegate layer:self didReceiveError:TLSError];
	}
	
	if ([self.delegate respondsToSelector:@selector(layerDidOpen:)])
		[self.delegate layerDidOpen:self];
}

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data context:(void *)context {
	if (context == &_AFHTTPClientWritePartialRequestContext) {
		// nop
	} else if (context == &_AFHTTPClientWriteRequestContext) {
		// nop
	} else [super layer:layer didWrite:data context:context];
}

- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data context:(void *)context {
	if (context == &_AFHTTPClientReadPartialResponseContext) {
		// nop
	} else if (context == &_AFHTTPClientReadResponseContext) {
		if ([self.delegate respondsToSelector:@selector(connection:didReceiveResponse:)])
			[self.delegate connection:self didReceiveResponse:(CFHTTPMessageRef)data];
	
		[self.transactionQueue dequeued];
		[self.transactionQueue tryDequeue];
	} else [super layer:layer didRead:data context:context];
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
	NSURL *resourcePath = [NSURL URLWithString:([resource isEmpty] ? @"/" : resource) relativeToURL:endpoint];
	
	CFHTTPMessageRef request = (CFHTTPMessageRef)[NSMakeCollectable(CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)HTTPMethod, (CFURLRef)resourcePath, kCFHTTPVersion1_1)) autorelease];
	
	for (NSString *currentKey in headers) {
		NSString *currentValue = [headers objectForKey:currentKey];
		CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)currentKey, (CFStringRef)currentValue);
	}
	
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
