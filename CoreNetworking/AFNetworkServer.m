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
#import <objc/runtime.h>

#import "AFNetworkSocket.h"
#import "AFNetworkTransport.h"
#import	"AFNetworkTypes.h"
#import "AFNetworkFunctions.h"
#import "AFNetworkPool.h"
#import "AFNetworkConnection.h"

#import "AFNetworkMacros.h"

// Note: import this header last, allowing for any of the previous headers to import <net/if.h> see the getifaddrs man page for details
#import <ifaddrs.h>

CORENETWORKING_NSSTRING_CONTEXT(AFNetworkServerHostConnectionsPropertyObservationContext);

@interface AFNetworkServer () <AFConnectionLayerControlDelegate>
@property (readonly) NSArray *encapsulationClasses;
@end

@interface AFNetworkServer (Private)
- (NSUInteger)_bucketContainingLayer:(id)layer;
@end

@implementation AFNetworkServer

@synthesize delegate=_delegate;
@synthesize encapsulationClasses=_encapsulationClasses, clientPools=_clientPools;

+ (NSSet *)localhostInternetSocketAddresses {
	CFHostRef localhost = (CFHostRef)[NSMakeCollectable(CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)@"localhost")) autorelease];
	
	CFStreamError error = {0};
	
	Boolean resolved = CFHostStartInfoResolution(localhost, (CFHostInfoType)kCFHostAddresses, &error);
	if (!resolved) return nil;
	
	return [NSSet setWithArray:(NSArray *)CFHostGetAddressing(localhost, NULL)];
}

+ (NSSet *)allInternetSocketAddresses {
	NSMutableSet *networkAddresses = [NSMutableSet set];
	
	struct ifaddrs *addrs = NULL;
	int error = getifaddrs(&addrs);
	if (error != 0) return nil;
	
	struct ifaddrs *currentInterfaceAddress = addrs;
	for (; currentInterfaceAddress != NULL; currentInterfaceAddress = currentInterfaceAddress->ifa_next) {
		struct sockaddr *currentAddr = currentInterfaceAddress->ifa_addr;
		if (currentAddr->sa_family == AF_LINK) continue;
		
		NSData *currentNetworkAddress = [NSData dataWithBytes:((void *)currentAddr) length:(currentAddr->sa_len)];
		[networkAddresses addObject:currentNetworkAddress];
	}
	
	freeifaddrs(addrs);
	
	return networkAddresses;
}

+ (id)server {
	return [[[AFNetworkServer alloc] initWithEncapsulationClass:[AFNetworkTransport class]] autorelease];
}

#pragma mark -

- (id)initWithEncapsulationClass:(Class)clientClass {
	self = [self init];
	if (self == nil) return nil;
	
	NSMutableArray *encapsulation = [[NSMutableArray alloc] initWithObjects:clientClass, nil];
	for (id lowerLayer = [clientClass lowerLayer]; lowerLayer != Nil; lowerLayer = [lowerLayer lowerLayer]){
		[encapsulation insertObject:lowerLayer atIndex:0];
	}
	_encapsulationClasses = encapsulation;
	
	NSMutableArray *pools = [[NSMutableArray alloc] initWithCapacity:[encapsulation count]];
	for (NSUInteger index = 0; index < [encapsulation count]; index++) {
		AFNetworkPool *currentPool = [[[AFNetworkPool alloc] init] autorelease];
		[pools addObject:currentPool];
	}
	[[pools lastObject] addObserver:self forKeyPath:@"connections" options:(NSKeyValueObservingOptionNew) context:&AFNetworkServerHostConnectionsPropertyObservationContext];
	_clientPools = pools;
	
	return self;
}

- (void)dealloc {	
	[_encapsulationClasses release];
	
	[[_clientPools lastObject] removeObserver:self forKeyPath:@"connections"];
	[_clientPools release];
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &AFNetworkServerHostConnectionsPropertyObservationContext) {
		if (![[change objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue] == NSKeyValueChangeInsertion) return;
		
		[[change valueForKey:NSKeyValueChangeNewKey] makeObjectsPerformSelector:@selector(setDelegate:) withObject:self];
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (AFPriorityProxy *)delegateProxy:(AFPriorityProxy *)proxy {	
	if (_delegate == nil) return proxy;
	
	if (proxy == nil) proxy = [[[AFPriorityProxy alloc] init] autorelease];
	
	if ([_delegate respondsToSelector:@selector(delegateProxy:)]) proxy = [(id)_delegate delegateProxy:proxy];
	[proxy insertTarget:_delegate];
	
	return proxy;
}

- (id)delegate {
	return [self delegateProxy:nil];
}

- (BOOL)openInternetSocketsWithTransportSignature:(AFNetworkInternetTransportSignature)signature addresses:(NSSet *)sockaddrs {
	return [self openInternetSocketsWithSocketSignature:signature.type port:&signature.port addresses:sockaddrs];
}

- (BOOL)openInternetSocketsWithSocketSignature:(const AFNetworkSocketSignature)signature port:(SInt32 *)port addresses:(NSSet *)sockaddrs {
	BOOL completeSuccess = YES;
	
	for (NSData *currentAddress in sockaddrs) {
		currentAddress = [[currentAddress mutableCopy] autorelease];
		
// Note: explicit cast to sockaddr_in, this *will* work for both IPv4 and IPv6 as the port is in the same location, however investigate alternatives
		
		((struct sockaddr_in *)CFDataGetMutableBytePtr((CFMutableDataRef)currentAddress))->sin_port = htons(*port);
		
		AFNetworkSocket *socket = [self openSocketWithSignature:signature address:currentAddress];
		
		if (socket == nil) {
			completeSuccess = NO;
			continue;
		}
		
		// Note: get the port after setting the address i.e. opening
		if (*port == 0) {
			// Note: extract the *actual* port used and use that for future sockets
			CFDataRef actualAddress = (CFDataRef)socket.localAddress;
			*port = ntohs(((struct sockaddr_in *)CFDataGetBytePtr(actualAddress))->sin_port);
		}
	}
	
	return completeSuccess;
}

- (BOOL)openPathSocketWithLocation:(NSURL *)location {
	NSParameterAssert([location isFileURL]);
	
	AFNetworkSocketSignature signature = (AFNetworkSocketSignature){
		.socketType = SOCK_STREAM,
		.protocol = 0,
	};
	
	struct sockaddr_un address = {0};
	
	unsigned int maximumLength = sizeof(address.sun_path);
	if (strlen([[location path] fileSystemRepresentation]) >= maximumLength) {
		[NSException raise:NSInvalidArgumentException format:@"%s, (%@) must be < %ld characters including the NUL terminator", __PRETTY_FUNCTION__, [location path], maximumLength, nil];
		return NO;
	}
	
	address.sun_family = AF_UNIX;
	strcpy(address.sun_path, [[location path] fileSystemRepresentation]);
	address.sun_len = SUN_LEN(&address);
	
	return ([self openSocketWithSignature:signature address:[NSData dataWithBytes:&address length:address.sun_len]] != nil);
}

- (AFNetworkSocket *)openSocketWithSignature:(const AFNetworkSocketSignature)signature address:(NSData *)address {	
	struct sockaddr addr = {0};
	[address getBytes:&addr length:sizeof(struct sockaddr)];
	
	CFSocketSignature socketSignature = {
		.socketType = signature.socketType,
		.protocol = signature.protocol,
		
		.protocolFamily = addr.sa_family,
		.address = (CFDataRef)address,
	};
	
	AFNetworkSocket *socket = [[[AFNetworkSocket alloc] initWithHostSignature:&socketSignature] autorelease];
	if (socket == nil) return nil;
	
	[[self.clientPools objectAtIndex:0] addConnectionsObject:socket];
	
	[socket setDelegate:(id)self];
	[socket open];
	
	return socket;
}

- (void)encapsulateNetworkLayer:(id <AFConnectionLayer>)layer {
	NSUInteger nextBucket = ([self.encapsulationClasses indexOfObject:[layer class]] + 1);
	if (nextBucket >= [self.encapsulationClasses count]) return;
	
	Class encapsulationClass = [self.encapsulationClasses objectAtIndex:nextBucket];
	
	id <AFConnectionLayer> newConnection = [[[encapsulationClass alloc] initWithLowerLayer:layer] autorelease];
	
	[[self.clientPools objectAtIndex:nextBucket] addConnectionsObject:newConnection];
	
	if ([self.delegate respondsToSelector:@selector(server:didEncapsulateLayer:)])
		[self.delegate server:self didEncapsulateLayer:newConnection];
	
	[newConnection setDelegate:(id)self];
	[newConnection open];
}

#pragma mark -
#pragma mark Delegate

- (void)layer:(id)layer didAcceptConnection:(id <AFConnectionLayer>)newLayer {
	NSUInteger bucket = [self _bucketContainingLayer:layer];
	
	if (bucket == NSUIntegerMax || bucket == [self.clientPools count]) {
		if ([self.delegate respondsToSelector:@selector(layer:didAcceptConnection:)])
			[self.delegate layer:self didAcceptConnection:newLayer];
		return;
	}
	
	if ([self.delegate respondsToSelector:@selector(server:shouldAcceptConnection:)]) {
		if (![self.delegate server:self shouldAcceptConnection:newLayer]) {
			[newLayer close];
			return;
		}
	}
	
	[self encapsulateNetworkLayer:newLayer];
}

- (void)layerDidOpen:(id <AFTransportLayer>)layer {
	if ([self _bucketContainingLayer:layer] == 0) return; // Note: these are the initial socket layers opening, nothing else is spawned at this layer
	[self encapsulateNetworkLayer:(id)layer];
}

- (void)layerDidClose:(id <AFConnectionLayer>)layer {
	NSUInteger bucket = [self _bucketContainingLayer:layer];
	
	if (layer.lowerLayer != nil) {
		id <AFTransportLayer> lowerLayer = [layer lowerLayer];
		
		lowerLayer.delegate = (id)self;
		[lowerLayer close];
	}
	
	[[self.clientPools objectAtIndex:bucket] removeConnectionsObject:layer];
}

@end

@implementation AFNetworkServer (Private)

- (NSUInteger)_bucketContainingLayer:(id)layer {
	for (NSUInteger index = 0; index < [self.clientPools count]; index++) {
		if (![[[self.clientPools objectAtIndex:index] connections] containsObject:layer]) continue;
		return index;
	}
	
	return NSUIntegerMax;
}

@end
