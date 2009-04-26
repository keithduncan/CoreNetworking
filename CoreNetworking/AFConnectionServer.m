//
//  ANServer.m
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnectionServer.h"

#import <sys/socket.h>
#import <arpa/inet.h>

#import "AFSocket.h"
#import "AFSocketConnection.h"

#import	"AFNetworkTypes.h"
#import "AFNetworkFunctions.h"
#import "AFConnectionPool.h"

#import "AFPriorityProxy.h"

// Note: import this header last, allowing for any of the previous headers to import <net/if.h> see the getifaddrs man page for details
#import <ifaddrs.h>

#warning this class should also provide the ability to listen for IP-layer changes and autoreconfigure

static void *ServerHostConnectionsPropertyObservationContext = (void *)@"ServerHostConnectionsPropertyObservationContext";

@interface AFConnectionServer () <AFConnectionLayerControlDelegate>
@property (readwrite, assign) Class clientClass;
@property (readwrite, retain) AFConnectionServer *lowerLayer;
@end

@implementation AFConnectionServer

@synthesize delegate=_delegate;
@synthesize clientClass=_clientClass;
@synthesize lowerLayer=_lowerLayer;
@synthesize clients, hosts;

+ (NSSet *)localhostSocketAddresses {
	CFHostRef localhost = CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)@"localhost");
	
	CFStreamError error;
	memset(&error, 0, sizeof(CFStreamError));
	
	Boolean resolved = CFHostStartInfoResolution(localhost, (CFHostInfoType)kCFHostAddresses, &error);
	if (!resolved) return nil;
	
	return [NSSet setWithArray:(NSArray *)CFHostGetAddressing(localhost, NULL)];
}

+ (NSSet *)networkSocketAddresses {
	NSMutableSet *networkAddresses = [NSMutableSet set];
	NSSet *localhostAddresses = [[self class] localhostSocketAddresses];
	
	struct ifaddrs *addrs = NULL;
	int error = getifaddrs(&addrs);
	if (error != 0) return nil;
	
	struct ifaddrs *currentInterfaceAddress = addrs;
	for (; currentInterfaceAddress != NULL; currentInterfaceAddress = currentInterfaceAddress->ifa_next) {
		struct sockaddr *currentAddr = currentInterfaceAddress->ifa_addr;
		if (currentAddr->sa_family == AF_LINK) continue;
		
		BOOL shouldSkipNetworkAddress = NO;
		for (NSData *currentLocalhostAddress in localhostAddresses) {
			struct sockaddr *currentLocalhostAddr = (struct sockaddr *)[currentLocalhostAddress bytes];
			shouldSkipNetworkAddress = sockaddr_compare(currentAddr, currentLocalhostAddr);
			if (shouldSkipNetworkAddress) break;
		} if (shouldSkipNetworkAddress) continue;
		
		NSData *currentNetworkAddress = [NSData dataWithBytes:((void *)currentAddr) length:(currentAddr->sa_len)];
		[networkAddresses addObject:currentNetworkAddress];
	}
	
	freeifaddrs(addrs);
	
	return networkAddresses;
}

- (id)init {
	return [self initWithLowerLayer:nil encapsulationClass:[AFSocketConnection class]];
}

- (id)initWithLowerLayer:(AFConnectionServer *)server encapsulationClass:(Class)clientClass {
	self = [super init]; // Note to self, this is intentionally sent to super
	
	hosts = [[AFConnectionPool alloc] init];
	[hosts addObserver:self forKeyPath:@"connections" options:(NSKeyValueObservingOptionNew) context:&ServerHostConnectionsPropertyObservationContext];
	
	clients = [[AFConnectionPool alloc] init];
	
	_lowerLayer = [server retain];
	[_lowerLayer setDelegate:self];
	
	_clientClass = clientClass;
	
	return self;
}

- (void)finalize {
	[self.clients disconnect];
	
	[super finalize];
}

- (void)dealloc {
	[self finalize];
	
	[_proxy release];
	
	[_lowerLayer release];
	
	[clients release];
	
	[hosts removeObserver:self forKeyPath:@"connections"];
	[hosts disconnect];
	
	[hosts release];
	
	[super dealloc];
}

- (AFPriorityProxy *)delegateProxy:(AFPriorityProxy *)proxy {
	if (proxy == nil) proxy = [[[AFPriorityProxy alloc] init] autorelease];
	
	if ([_delegate respondsToSelector:@selector(delegateProxy:)]) [(id)_delegate delegateProxy:proxy];
	[proxy insertTarget:_delegate atPriority:0];
	
	return proxy;
}

- (id <AFConnectionServerDelegate>)delegate {
	return (id)[self delegateProxy:nil];
}

- (id)forwardingTargetForSelector:(SEL)selector {
	return self.lowerLayer;
}

- (BOOL)respondsToSelector:(SEL)selector {
	return ([super respondsToSelector:selector] || [[self forwardingTargetForSelector:selector] respondsToSelector:selector]);
}

- (void)openSockets:(const AFSocketTransport *)signature addresses:(NSSet *)sockAddrs {
	SInt32 port = signature->port;
	[self openSockets:&port withType:signature->type addresses:sockAddrs];
}

- (void)openSockets:(SInt32 *)port withType:(const AFSocketType *)type addresses:(NSSet *)sockAddrs {
	AFConnectionServer *lowestLayer = self;
	while (lowestLayer.lowerLayer != nil) lowestLayer = lowestLayer.lowerLayer;
	self = lowestLayer;
	
	for (NSData *currentAddrData in sockAddrs) {
		currentAddrData = [[currentAddrData mutableCopy] autorelease];
		((struct sockaddr_in *)CFDataGetMutableBytePtr((CFMutableDataRef)currentAddrData))->sin_port = htons(*port);
		// FIXME: #warning explicit cast to sockaddr_in, this *will* work for both IPv4 and IPv6 as the port is in the same location, however investigate alternatives
		
		CFSocketSignature currentSocketSignature = {
			.protocolFamily = ((const struct sockaddr *)CFDataGetBytePtr((CFDataRef)currentAddrData))->sa_family,
			.socketType = type->socketType,
			.protocol = type->protocol,
			.address = (CFDataRef)currentAddrData,
		};
		
		AFSocket *socket = [[AFSocket alloc] initWithSignature:&currentSocketSignature callbacks:kCFSocketAcceptCallBack delegate:self];
		if (socket == nil) continue;
		
		[socket scheduleInRunLoop:CFRunLoopGetCurrent() forMode:kCFRunLoopDefaultMode];
		
		[self.hosts addConnectionsObject:socket];
		[socket open];
		
		// Note: get the port after setting the address i.e. opening
		if (*port == 0) {
			// Note: extract the *actual* port used and use that for future allocations
			CFDataRef actualAddrData = CFSocketCopyAddress((CFSocketRef)[socket lowerLayer]);
			*port = ntohs(((struct sockaddr_in *)CFDataGetBytePtr(actualAddrData))->sin_port);
			CFRelease(actualAddrData);
		}
		
		[socket release];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &ServerHostConnectionsPropertyObservationContext) {
		if (![[change objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue] == NSKeyValueChangeInsertion) return;
		
		[[change valueForKey:NSKeyValueChangeNewKey] makeObjectsPerformSelector:@selector(setDelegate:) withObject:self];
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (id <AFConnectionLayer>)newApplicationLayerForNetworkLayer:(id <AFConnectionLayer>)newLayer {
	return [[[[self clientClass] alloc] initWithLowerLayer:newLayer delegate:(id)self] autorelease];
}

- (void)layer:(id)layer didAcceptConnection:(id <AFConnectionLayer>)newLayer {
	if ([self.delegate respondsToSelector:@selector(server:shouldAcceptConnection:fromHost:)]) {
		CFHostRef host = (CFHostRef)[(id)newLayer peer];
		if (![self.delegate server:self shouldAcceptConnection:newLayer fromHost:host]) return;
	}
	
	id <AFConnectionLayer> newConnection = [self newApplicationLayerForNetworkLayer:newLayer];
	[self.clients addConnectionsObject:newConnection];
	
	if ([newConnection respondsToSelector:@selector(scheduleInRunLoop:forMode:)])
		[newConnection scheduleInRunLoop:CFRunLoopGetCurrent() forMode:kCFRunLoopDefaultMode];
	
	[newConnection open];
}

- (void)layer:(id <AFConnectionLayer>)layer didConnectToPeer:(id)host {
	if ([self.delegate respondsToSelector:@selector(layer:didAcceptConnection:)])
		[self.delegate layer:self didAcceptConnection:layer];
}

- (void)layerDidClose:(id <AFConnectionLayer>)layer {
	if (![self.clients.connections containsObject:layer]) return;
	
	layer = [[layer retain] autorelease];
	[self.clients removeConnectionsObject:layer];
	
	if (self.lowerLayer != nil) {
		layer = layer.lowerLayer;
		layer.delegate = self.lowerLayer;
		
		[layer close];
	}
}

@end
