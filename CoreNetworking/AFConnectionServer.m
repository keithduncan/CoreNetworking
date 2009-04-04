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
#import "AFConnectionPool.h"

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
	
	[_lowerLayer release];
	
	[clients release];
	
	[hosts removeObserver:self forKeyPath:@"connections"];
	[hosts disconnect];
	
	[hosts release];
	
	[super dealloc];
}

- (id)_openSockets:(SInt32 *)port withType:(struct AFSocketType)type addresses:(NSArray *)addrs {
	AFConnectionServer *lowestLayer = self;
	while (lowestLayer.lowerLayer != nil) {
		lowestLayer = self.lowerLayer;
	} self = lowestLayer;
	
	for (NSData *currentAddrData in addrs) {
		currentAddrData = [[currentAddrData mutableCopy] autorelease];
		((struct sockaddr_in *)CFDataGetMutableBytePtr((CFMutableDataRef)currentAddrData))->sin_port = htons(*port);
		// Note #warning explicit cast to sockaddr_in, this *will* work for both IPv4 and IPv6 as the port is in the same location, however investigate alternatives
		
		CFSocketSignature currentSocketSignature = {
			.protocolFamily = ((const struct sockaddr *)CFDataGetBytePtr((CFDataRef)currentAddrData))->sa_family,
			.socketType = type.socketType,
			.protocol = type.protocol,
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
			// Note #warning explicit cast to sockaddr_in, this *will* work for both IPv4 and IPv6 as the port is in the same location, however investigate alternatives
			CFRelease(actualAddrData);
		}
		
		[socket release];
	}
}

- (id)openNetworkSockets:(SInt32 *)port withType:(struct AFSocketType)type {
	NSMutableArray *addresses = [NSMutableArray array];
	
	struct ifaddrs *addrs = NULL;
	int error = getifaddrs(&addrs);
	if (error != 0) return nil;
	
	struct ifaddrs *currentAddr = addrs;
	for (; currentAddr != NULL; currentAddr = currentAddr->ifa_next) {
		if (currentAddr->ifa_addr->sa_family == AF_LINK) continue;
		[addresses addObject:[NSData dataWithBytes:((void *)currentAddr->ifa_addr) length:(currentAddr->ifa_addr->sa_len)]];
	}
	
	[self _openSockets:port withType:type addresses:addresses];
	
	freeifaddrs(addrs);
}

- (id)openLocalhostSockets:(SInt32 *)port withType:(struct AFSocketType)type {
	CFHostRef localhost = CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)@"localhost");
	
	CFStreamError error;
	memset(&error, 0, sizeof(CFStreamError));
	
	Boolean resolved = CFHostStartInfoResolution(localhost, (CFHostInfoType)kCFHostAddresses, &error);
	if (!resolved) return nil;
	
	[self _openSockets:port withType:type addresses:(NSArray *)CFHostGetAddressing(localhost, NULL)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &ServerHostConnectionsPropertyObservationContext) {
		if (![[change objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue] == NSKeyValueChangeInsertion) return;
		
		[[change valueForKey:NSKeyValueChangeNewKey] makeObjectsPerformSelector:@selector(setDelegate:) withObject:self];
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (id <AFConnectionLayer>)newApplicationLayerForNetworkLayer:(id <AFConnectionLayer>)newLayer {
	return [[[[self clientClass] alloc] initWithLowerLayer:newLayer delegate:self] autorelease];
}

- (void)layer:(id)layer didAcceptConnection:(id <AFConnectionLayer>)newLayer {
	id <AFConnectionLayer> newConnection = [self newApplicationLayerForNetworkLayer:newLayer];
	[self.clients addConnectionsObject:newConnection];
	
	if ([newConnection respondsToSelector:@selector(scheduleInRunLoop:forMode:)])
		[newConnection scheduleInRunLoop:CFRunLoopGetCurrent() forMode:kCFRunLoopDefaultMode];
	
	[newConnection open];
}

- (void)layer:(id <AFConnectionLayer>)layer didConnectToPeer:(const CFHostRef)host {
	BOOL shouldConnect = YES;
	if ([self.delegate respondsToSelector:@selector(server:shouldConnect:toHost:)])
		shouldConnect = [self.delegate server:self shouldConnect:layer toHost:host];
	
	if (!shouldConnect) {
		[self.clients removeConnectionsObject:layer];
		return;
	}
	
	if ([self.delegate respondsToSelector:@selector(layer:didAcceptConnection:)])
		[self.delegate layer:self didAcceptConnection:socket];
}

- (void)layerDidClose:(id <AFConnectionLayer>)layer {
	if (![self.clients.connections containsObject:layer]) return;
	[self.clients removeConnectionsObject:layer];
}

@end
