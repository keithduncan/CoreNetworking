//
//  AFConnectionServer.m
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008. All rights reserved.
//

#import "AFNetworkServer.h"

#import <sys/socket.h>
#import <sys/un.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <objc/runtime.h>

#import "AFNetworkSocket.h"
#import "AFNetworkTransport.h"
#import "AFNetworkPool.h"
#import "AFNetworkConnection.h"

#import "AFNetworkSchedulerProxy.h"
#import "AFNetworkDelegateProxy.h"

#import	"AFNetwork-Types.h"
#import "AFNetwork-Functions.h"
#import "AFNetwork-Constants.h"
#import "AFNetwork-Macros.h"

@interface AFNetworkServer () <AFNetworkConnectionLayerHostDelegate, AFNetworkConnectionLayerControlDelegate>
@property (retain, nonatomic) NSArray *encapsulationClasses;
@property (readwrite, retain, nonatomic) NSArray *clientPools;
@end

@interface AFNetworkServer (AFNetworkPrivate)
- (void)_observeClientPools:(NSArray *)clientPools;
- (void)_unobserveClientPools:(NSArray *)clientPools;

- (void)_scheduleLayer:(AFNetworkLayer *)layer;

- (void)_initialiseWithEncapsulationClass:(Class)encapsulationClass;
- (NSInteger)_bucketContainingLayer:(id)layer;
@end

@implementation AFNetworkServer

static NSString *const _AFNetworkServerClientPoolsKey = @"clientPools";

AFNETWORK_NSSTRING_CONTEXT(_AFNetworkServerClientPoolsObservationContext);
AFNETWORK_NSSTRING_CONTEXT(_AFNetworkServerPoolConnectionsObservationContext);

@synthesize encapsulationClasses=_encapsulationClasses, clientPools=_clientPools;

@synthesize scheduler=_scheduler;
@synthesize delegate=_delegate;

+ (id)server {
	return [[[AFNetworkServer alloc] initWithEncapsulationClass:[AFNetworkTransport class]] autorelease];
}

#pragma mark -

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_scheduler = [[AFNetworkSchedulerProxy alloc] init];
#if 0
	[_scheduler scheduleInQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
#else
	[_scheduler scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
#endif
	
	[self _initialiseWithEncapsulationClass:[AFNetworkTransport class]];
	
	[self addObserver:self forKeyPath:_AFNetworkServerClientPoolsKey options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:&_AFNetworkServerClientPoolsObservationContext];
	
	return self;
}

- (id)initWithEncapsulationClass:(Class)encapsulationClass {
	self = [self init];
	if (self == nil) return nil;
	
	[self _initialiseWithEncapsulationClass:encapsulationClass];
	
	return self;
}

- (void)dealloc {	
	[_scheduler release];
	
	[self removeObserver:self forKeyPath:_AFNetworkServerClientPoolsKey];
	[self _unobserveClientPools:_clientPools];
	
	[_encapsulationClasses release];
	[_clientPools release];
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context == &_AFNetworkServerClientPoolsObservationContext) {
		id oldClientPools = [change objectForKey:NSKeyValueChangeOldKey];
		if ([oldClientPools isEqual:[NSNull null]]) {
			oldClientPools = nil;
		}
		[self _unobserveClientPools:oldClientPools];
		
		id newClientPools = [change objectForKey:NSKeyValueChangeNewKey];
		if ([newClientPools isEqual:[NSNull null]]) {
			newClientPools = nil;
		}
		[self _observeClientPools:newClientPools];
	}
	else if (context == &_AFNetworkServerPoolConnectionsObservationContext) {
		if (object == [[self clientPools] objectAtIndex:0]) {
			return;
		}
		if ([[change objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue] != NSKeyValueChangeInsertion) {
			return;
		}
		
		id newObjects = [change valueForKey:NSKeyValueChangeNewKey];
		if (newObjects == nil || [newObjects isEqual:[NSNull null]]) {
			return;
		}
		
		for (AFNetworkLayer *currentNetworkLayer in newObjects) {
			[self _scheduleLayer:currentNetworkLayer];
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (AFNetworkDelegateProxy *)delegateProxy:(AFNetworkDelegateProxy *)proxy {	
	if (_delegate == nil) {
		return proxy;
	}
	
	if (proxy == nil) {
		proxy = [[[AFNetworkDelegateProxy alloc] init] autorelease];
	}
	
	[proxy insertTarget:self];
	
	if ([_delegate respondsToSelector:@selector(delegateProxy:)]) {
		proxy = [(id)_delegate delegateProxy:proxy];
	}
	
	[proxy insertTarget:_delegate];
	
	return proxy;
}

- (id)delegate {
	return [self delegateProxy:nil];
}

- (BOOL)openInternetSocketsWithSocketSignature:(AFNetworkSocketSignature const)socketSignature scope:(AFNetworkInternetSocketScope)scope port:(uint16_t)port errorHandler:(BOOL (^)(NSData *, NSError *))errorHandler {
	struct addrinfo hints = {
		.ai_family = AF_UNSPEC,
		.ai_socktype = socketSignature.socketType,
		.ai_flags = AI_PASSIVE,
	};
	struct addrinfo *addresses = NULL;
	
	char const *nodename = NULL;
	if (scope == AFNetworkInternetSocketScopeLocalOnly) {
		nodename = "localhost";
	}
	else if (scope == AFNetworkInternetSocketScopeGlobal) {
		nodename = NULL;
	}
	else {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"unknown address scope %ld", (unsigned long)scope] userInfo:nil];
		return NO;
	}
	
	char const *servname = [[NSString stringWithFormat:@"%hu", port] UTF8String];
	
	int getaddrinfoError = getaddrinfo(nodename, servname, &hints, &addresses);
	if (getaddrinfoError != 0) {
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   [NSNumber numberWithInteger:getaddrinfoError], (id)kCFGetAddrInfoFailureKey,
								   nil];
		NSError *error = [NSError errorWithDomain:(id)kCFErrorDomainCFNetwork code:kCFHostErrorUnknown userInfo:errorInfo];
		
		NSError *displayError = AFNetworkStreamPrepareDisplayError(nil, error);
		
		if (errorHandler != nil) {
			errorHandler(nil, displayError);
		}
		
		return NO;
	}
	
	NSMutableSet *socketAddresses = [NSMutableSet set];
	for (struct addrinfo *currentAddressInfo = addresses; currentAddressInfo != NULL; currentAddressInfo = currentAddressInfo->ai_next) {
		NSData *currentAddressData = [NSData dataWithBytes:currentAddressInfo->ai_addr length:currentAddressInfo->ai_addrlen];
		[socketAddresses addObject:currentAddressData];
	}
	
	freeaddrinfo(addresses);
	
	return [self openInternetSocketsWithSocketSignature:socketSignature socketAddresses:socketAddresses errorHandler:errorHandler];
}

- (BOOL)openInternetSocketsWithSocketSignature:(AFNetworkSocketSignature const)socketSignature socketAddresses:(NSSet *)socketAddresses errorHandler:(BOOL (^)(NSData *, NSError *))errorHandler {
	NSMutableSet *socketObjects = [NSMutableSet setWithCapacity:[socketAddresses count]];
	BOOL shouldCloseSocketObjects = NO;
	
	for (NSData *currentSocketAddress in socketAddresses) {
		currentSocketAddress = [[currentSocketAddress mutableCopy] autorelease];
		
		NSError *currentSocketObjectError = nil;
		AFNetworkSocket *currentSocketObject = [self openSocketWithSignature:socketSignature address:currentSocketAddress error:&currentSocketObjectError];
		if (currentSocketObject == nil) {
			if (errorHandler != nil) {
				BOOL errorHandlerValue = errorHandler(currentSocketAddress, currentSocketObjectError);
				if (!errorHandlerValue) {
					shouldCloseSocketObjects = YES;
					break;
				}
				
				continue;
			}
			
			shouldCloseSocketObjects = YES;
			break;
		}
		
		[socketObjects addObject:currentSocketObject];
	}
	
	if (shouldCloseSocketObjects) {
		[socketObjects makeObjectsPerformSelector:@selector(close)];
		return NO;
	}
	
	return YES;
}

- (BOOL)openPathSocketWithLocation:(NSURL *)location error:(NSError **)errorRef {
	NSParameterAssert([location isFileURL]);
	
	AFNetworkSocketSignature signature = (AFNetworkSocketSignature){
		.socketType = SOCK_STREAM,
		.protocol = 0,
	};
	
	struct sockaddr_un address = {};
	unsigned int maximumLength = sizeof(address.sun_path);
	if (strlen([[location path] fileSystemRepresentation]) >= maximumLength) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s, (%@) must be < %lu characters including the NUL terminator", __PRETTY_FUNCTION__, [location path], (unsigned long)maximumLength] userInfo:nil];
		return NO;
	}
	
	address.sun_family = AF_UNIX;
	strlcpy(address.sun_path, [[location path] fileSystemRepresentation], sizeof(address.sun_path));
	address.sun_len = SUN_LEN(&address);
	
	AFNetworkSocket *socket = [self openSocketWithSignature:signature address:[NSData dataWithBytes:&address length:address.sun_len] error:errorRef];
	if (socket == nil) {
		return NO;
	}
	
	return YES;
}

- (AFNetworkSocket *)openSocketWithSignature:(AFNetworkSocketSignature const)signature address:(NSData *)address error:(NSError **)errorRef {
	NSParameterAssert(self.clientPools != nil);
	
	CFRetain(address);
	
	unsigned long protocolFamily = ((struct sockaddr_storage const *)[address bytes])->ss_family;
	
	CFSocketSignature socketSignature = {
		.socketType = signature.socketType,
		.protocol = signature.protocol,
		
		.protocolFamily = protocolFamily,
		.address = (CFDataRef)address,
	};
	
	AFNetworkSocket *newSocket = [[[AFNetworkSocket alloc] initWithSocketSignature:&socketSignature] autorelease];
	
	CFRelease(address);
	
	if (newSocket == nil) {
		if (errorRef != NULL) {
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									   [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Couldn\u2019t open socket with protocol family \u201c%ld\u201d", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkServer open socket protocol family not supported"), (unsigned long)protocolFamily], NSLocalizedDescriptionKey,
									   nil];
			*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkErrorUnknown userInfo:errorInfo];
		}
		return nil;
	}
	
	[self _scheduleLayer:newSocket];
	
	BOOL open = [newSocket open:errorRef];
	if (!open) {
		return nil;
	}
	
	AFNetworkPool *listenPool = [self.clientPools objectAtIndex:0];
	[listenPool addConnectionsObject:newSocket];
	
	return newSocket;
}

- (void)closeListenSockets {
	AFNetworkPool *listenPool = [self.clientPools objectAtIndex:0];
	for (AFNetworkSocket *currentLayer in listenPool.connections) {
		[currentLayer close];
		[listenPool removeConnectionsObject:currentLayer];
	}
}

- (void)close {
	[self closeListenSockets];
	
	AFNetworkPool *transportPool = [self.clientPools objectAtIndex:1];
	for (AFNetworkTransport *transportLayer in transportPool.connections) {
		[transportLayer close];
		[transportPool removeConnectionsObject:transportLayer];
	}
}

- (void)encapsulateNetworkLayer:(id <AFNetworkConnectionLayer>)layer {
	NSUInteger nextBucket = ([self.encapsulationClasses indexOfObject:[layer class]] + 1);
	if (nextBucket >= [self.encapsulationClasses count]) {
		return;
	}
	
	Class encapsulationClass = [self.encapsulationClasses objectAtIndex:nextBucket];
	id <AFNetworkConnectionLayer> newConnection = [[[encapsulationClass alloc] initWithLowerLayer:layer] autorelease];
	
	if ([self.delegate respondsToSelector:@selector(networkServer:didEncapsulateLayer:)]) {
		[self.delegate networkServer:self didEncapsulateLayer:newConnection];
	}
	
	[[self.clientPools objectAtIndex:nextBucket] addConnectionsObject:newConnection];
	[newConnection open];
}

#pragma mark - Delegate

- (void)networkLayer:(id)layer didAcceptConnection:(id <AFNetworkConnectionLayer>)connection {
	NSInteger bucket = [self _bucketContainingLayer:layer];
	
	if (bucket == 0) {
		if ([self.delegate respondsToSelector:@selector(networkServer:shouldAcceptConnection:)]) {
			if (![self.delegate networkServer:self shouldAcceptConnection:connection]) {
				[connection close];
				return;
			}
		}
		
		if ([self.delegate respondsToSelector:@selector(networkServer:didAcceptConnection:)]) {
			[self.delegate networkServer:self didAcceptConnection:connection];
		}
	}
	
	[self encapsulateNetworkLayer:connection];
}

- (void)networkLayerDidOpen:(id <AFNetworkTransportLayer>)layer {
	if ([self _bucketContainingLayer:layer] == NSNotFound) {
		// Note: these are the initial socket layers opening, nothing else is spawned at this layer
		return;
	}
	
	[self encapsulateNetworkLayer:(id)layer];
}

- (void)networkLayerDidClose:(id <AFNetworkConnectionLayer>)layer {
	NSInteger bucket = [self _bucketContainingLayer:layer];
	if (bucket == NSNotFound) {
		return;
	}
	[[self.clientPools objectAtIndex:bucket] removeConnectionsObject:layer];
	
	id <AFNetworkTransportLayer> lowerLayer = layer.lowerLayer;
	if (lowerLayer != nil) {
		[self networkLayerDidClose:lowerLayer];
	}
}

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didReceiveError:(NSError *)error {
	[(id)self.delegate networkLayer:layer didReceiveError:error];
}

@end

#pragma mark -

@implementation AFNetworkServer (AFNetworkPrivate)

- (void)_observeClientPools:(NSArray *)clientPools {
	for (AFNetworkPool *currentPool in clientPools) {
		[currentPool addObserver:self forKeyPath:@"connections" options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:&_AFNetworkServerPoolConnectionsObservationContext];
	}
}

- (void)_unobserveClientPools:(NSArray *)clientPools {
	for (AFNetworkPool *currentPool in clientPools) {
		[currentPool removeObserver:self forKeyPath:@"connections"];
	}
}

- (void)_scheduleLayer:(AFNetworkLayer *)layer {
	[self.scheduler scheduleNetworkLayer:(id)layer];
	layer.delegate = self;
}

- (void)_initialiseWithEncapsulationClass:(Class)encapsulationClass {
	NSMutableArray *newEncapsulationClasses = [NSMutableArray arrayWithObjects:encapsulationClass, nil];
	for (id lowerLayer = [encapsulationClass lowerLayerClass]; lowerLayer != Nil; lowerLayer = [lowerLayer lowerLayerClass]) {
		[newEncapsulationClasses insertObject:lowerLayer atIndex:0];
	}
	[self setEncapsulationClasses:newEncapsulationClasses];
	
	NSMutableArray *newClientPools = [NSMutableArray arrayWithCapacity:[newEncapsulationClasses count]];
	for (NSUInteger idx = 0; idx < [newEncapsulationClasses count]; idx++) {
		AFNetworkPool *currentPool = [[[AFNetworkPool alloc] init] autorelease];
		[newClientPools addObject:currentPool];
	}
	[self setClientPools:newClientPools];
}

- (NSInteger)_bucketContainingLayer:(id)layer {
	for (NSInteger idx = 0; idx < [self.clientPools count]; idx++) {
		if (![[[self.clientPools objectAtIndex:idx] connections] containsObject:layer]) {
			continue;
		}
		return idx;
	}
	
	return NSNotFound;
}

@end
