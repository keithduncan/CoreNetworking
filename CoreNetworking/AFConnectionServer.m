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
#import <objc/runtime.h>

#import "AFSocket.h"
#import "AFSocketTransport.h"

#import	"AFNetworkTypes.h"
#import "AFNetworkFunctions.h"
#import "AFConnectionPool.h"

#import "AFPriorityProxy.h"

// Note: import this header last, allowing for any of the previous headers to import <net/if.h> see the getifaddrs man page for details
#import <ifaddrs.h>

static void *ServerHostConnectionsPropertyObservationContext = (void *)@"ServerHostConnectionsPropertyObservationContext";

@interface AFConnectionServer () <AFConnectionLayerControlDelegate>
@property (readwrite, assign) Class clientClass;
@end

@implementation AFConnectionServer

@dynamic lowerLayer, delegate;
@synthesize clientClass=_clientClass;
@synthesize hosts, clients;

+ (NSSet *)localhostSocketAddresses {
	CFHostRef localhost = (CFHostRef)[NSMakeCollectable(CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)@"localhost")) autorelease];
	
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

+ (id)server {
	return [[[self alloc] initWithLowerLayer:nil encapsulationClass:[AFSocketTransport class]] autorelease];
}

- (id)initWithLowerLayer:(AFConnectionServer *)server encapsulationClass:(Class)clientClass {
	self = [self initWithLowerLayer:(id)server];
	if (self == nil) return nil;
	
	hosts = [[AFConnectionPool alloc] init];
	[hosts addObserver:self forKeyPath:@"connections" options:(NSKeyValueObservingOptionNew) context:&ServerHostConnectionsPropertyObservationContext];
	
	clients = [[AFConnectionPool alloc] init];
	
	_clientClass = clientClass;
	
	return self;
}

- (void)_close {
	[self.clients disconnect];
}

- (void)finalize {
	[self _close];
	
	[super finalize];
}

- (void)dealloc {
	[self _close];
	
	[clients release];
	
	[hosts removeObserver:self forKeyPath:@"connections"];
	[hosts disconnect];
	
	[hosts release];
	
	[super dealloc];
}

- (void)openSockets:(const AFSocketTransportSignature *)signature addresses:(NSSet *)sockAddrs {
	SInt32 port = signature->port;
	[self openSockets:&port withType:signature->type addresses:sockAddrs];
}

- (void)openSockets:(SInt32 *)port withType:(const AFSocketTransportType *)type addresses:(NSSet *)sockAddrs {
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
		
		AFSocket *socket = [[AFSocket alloc] initWithSignature:&currentSocketSignature callbacks:kCFSocketAcceptCallBack];
		if (socket == nil) continue;
		
		[self.hosts addConnectionsObject:socket];
		
		[socket open];
		
		// Note: get the port after setting the address i.e. opening
		if (*port == 0) {
			// Note: extract the *actual* port used and use that for future sockets allocations
			CFHostRef addrHost = (CFHostRef)[socket peer];
			CFDataRef actualAddrData = CFArrayGetValueAtIndex(CFHostGetAddressing(addrHost, NULL), 0);
			*port = ntohs(((struct sockaddr_in *)CFDataGetBytePtr(actualAddrData))->sin_port);
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
	id <AFConnectionLayer> connection = [[[[self clientClass] alloc] initWithLowerLayer:newLayer] autorelease];
	[connection setDelegate:(id)self];
	return connection;
}

- (void)layer:(id)layer didAcceptConnection:(id <AFConnectionLayer>)newLayer {
	if ([self.delegate respondsToSelector:@selector(server:shouldAcceptConnection:fromHost:)]) {
		CFHostRef host = (CFHostRef)[(id)newLayer peer];
		if (![self.delegate server:self shouldAcceptConnection:newLayer fromHost:host]) return;
	}
	
	id <AFConnectionLayer> newConnection = [self newApplicationLayerForNetworkLayer:newLayer];
	
	[self.clients addConnectionsObject:newConnection];
	[newConnection open];
}

- (void)layerDidOpen:(id <AFTransportLayer>)layer {
	
}

- (void)layerDidClose:(id <AFConnectionLayer>)layer {
	if (![self.clients.connections containsObject:layer]) return;
	
	if (self.lowerLayer != nil) {
		id <AFTransportLayer> lowerLayer = layer.lowerLayer;
		lowerLayer.delegate = (id)self.lowerLayer;
		[layer close];
	}
	
	[self.clients removeConnectionsObject:layer];
}

@end
