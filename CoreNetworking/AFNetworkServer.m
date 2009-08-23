//
//  AFConnectionServer.m
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFNetworkServer.h"

#import "AFNetworkSocket.h"
#import "AFNetworkTransport.h"
#import	"AFNetworkTypes.h"
#import "AFNetworkFunctions.h"
#import "AFNetworkPool.h"
#import "AFNetworkConnection.h"

#import <sys/socket.h>
#import <sys/un.h>
#import <arpa/inet.h>
#import <objc/runtime.h>
#import "AmberFoundation/AmberFoundation.h"

// Note: import this header last, allowing for any of the previous headers to import <net/if.h> see the getifaddrs man page for details
#import <ifaddrs.h>

static NSString *AFNetworkServerHostConnectionsPropertyObservationContext = @"ServerHostConnectionsPropertyObservationContext";

@interface AFNetworkServer () <AFConnectionLayerControlDelegate>
@property (readonly) NSArray *encapsulationClasses;
@property (readonly) NSArray *clientPools;
@end

@interface AFNetworkServer (Private)
- (NSUInteger)_bucketContainingLayer:(id)layer;
@end

@implementation AFNetworkServer

@synthesize delegate=_delegate;
//@synthesize bonjourDomains=_bonjourDomains, bonjourName=_bonjourName;
@synthesize encapsulationClasses=_encapsulationClasses, clientPools=_clientPools;

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

+ (NSSet *)localhostInternetSocketAddresses {
	CFHostRef localhost = (CFHostRef)[NSMakeCollectable(CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)@"localhost")) autorelease];
	
	CFStreamError error;
	memset(&error, 0, sizeof(CFStreamError));
	
	Boolean resolved = CFHostStartInfoResolution(localhost, (CFHostInfoType)kCFHostAddresses, &error);
	if (!resolved) return nil;
	
	return [NSSet setWithArray:(NSArray *)CFHostGetAddressing(localhost, NULL)];
}

+ (id)server {
	return [[[AFNetworkServer alloc] initWithEncapsulationClass:[AFNetworkTransport class]] autorelease];
}

#pragma mark -

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	//_bonjourDomains = [[NSMutableSet alloc] init];
	//_bonjourServices = [[NSMutableDictionary alloc] init];
	
	return self;
}

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
	//[_bonjourDomains release];
	//[_bonjourServices release];
	
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

- (AFNetworkPool *)clients {
	return [self.clientPools lastObject];
}

- (BOOL)openInternetSocketsWithTransportSignature:(AFInternetTransportSignature)signature addresses:(NSSet *)sockaddrs {
	return [self openInternetSocketsWithSocketSignature:signature.type port:&signature.port addresses:sockaddrs];
}

- (NSString *)_serviceDiscoveryType:(AFSocketSignature *)signature {
	NSString *protocolType = nil;
	if (AFSocketSignatureEqualToSignature(*signature, AFNetworkSocketSignatureTCP)) protocolType = @"_tcp";
	else if (AFSocketSignatureEqualToSignature(*signature, AFNetworkSocketSignatureUDP)) protocolType = @"_udp";
	else [NSException raise:NSInvalidArgumentException format:@"%s, (%p) is an invalid internet signature type", signature, nil];
	
	NSString *applicationType = [[[self encapsulationClasses] lastObject] serviceDiscoveryType];
	NSString *serviceType = [NSString stringWithFormat:@"%@.%@", applicationType, protocolType, nil];
	return serviceType;
}

- (BOOL)openInternetSocketsWithSocketSignature:(const AFSocketSignature *)signature port:(SInt32 *)port addresses:(NSSet *)sockaddrs {
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
	
#if 0
	if (self.bonjourName != nil) {		
		NSMutableSet *services = [NSMutableSet set];
		
		NSString *serviceType = [self _serviceDiscoveryType:signature];
		
		for (NSString *currentDomain in self.bonjourDomains) {
			CFNetServiceRef currentService = (CFNetServiceRef)[NSMakeCollectable(CFNetServiceCreate(kCFAllocatorDefault, (CFStringRef)currentDomain, (CFStringRef)serviceType, (CFStringRef)self.bonjourName, *port)) autorelease];
			[services addObject:(id)currentService];
		}
		
#error register the services
	}
#endif
	
	return completeSuccess;
}

- (BOOL)openPathSocketWithLocation:(NSURL *)location {
	NSParameterAssert([location isFileURL]);
	
	if (strlen([[location path] fileSystemRepresentation]) >= 104) {
		[NSException raise:NSInvalidArgumentException format:@"%s, (%@) must be < 104 characters including the NULL terminator", __PRETTY_FUNCTION__, [location path], nil];
		return NO;
	}
	
	struct sockaddr_un address;
	bzero(&address, sizeof(struct sockaddr_un));
	
	address.sun_family = AF_UNIX;
	strcpy(address.sun_path, [[location path] fileSystemRepresentation]);
	address.sun_len = SUN_LEN(&address);
	
	return ([self openSocketWithSignature:(AFSocketSignature *)&AFLocalSocketSignature address:[NSData dataWithBytes:&address length:address.sun_len]] != nil);
}

- (AFNetworkSocket *)openSocketWithSignature:(const AFSocketSignature *)signature address:(NSData *)address {	
	struct sockaddr addr;
	[address getBytes:&addr length:sizeof(struct sockaddr)];
	
	CFSocketSignature socketSignature = {
		.socketType = signature->socketType,
		.protocol = signature->protocol,
		
		.protocolFamily = addr.sa_family,
		.address = (CFDataRef)address,
	};
	
	AFNetworkSocket *socket = [[[AFNetworkSocket alloc] initWithSignature:&socketSignature callbacks:kCFSocketAcceptCallBack] autorelease];
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
	if ([self _bucketContainingLayer:layer] == 0) return;
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

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
	//[self.bonjourDomains addObject:domainString];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
	//[self.bonjourDomains removeObject:domainString];
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
