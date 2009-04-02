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
#import	"AFNetworkTypes.h"
#import "AFConnectionPool.h"

// Note: import this header last, allowing for any of the previous headers to import <net/if.h>
// Note: see the man page for getifaddrs
#import <ifaddrs.h>

static void *ServerHostConnectionsPropertyObservationContext = (void *)@"ServerHostConnectionsPropertyObservationContext";

@interface AFConnectionServer () <AFConnectionLayerControlDelegate>

@end

@implementation AFConnectionServer

@synthesize delegate=_delegate;
@synthesize clients, hosts;

+ (id)_serverWithPort:(SInt32 *)port socketType:(struct AFSocketType)type addresses:(CFArrayRef)addrs {
#warning this methods should also configure the server to listen for IP-layer changes
	AFConnectionServer *server = [[[self alloc] init] autorelease];
	
	for (NSData *currentAddrData in (NSArray *)addrs) {
		currentAddrData = [[currentAddrData mutableCopy] autorelease];
		((struct sockaddr_in *)CFDataGetMutableBytePtr((CFMutableDataRef)currentAddrData))->sin_port = htons(*port);
		// Note #warning explicit cast to sockaddr_in, this *will* work for both IPv4 and IPv6 as the port is in the same location, however investigate alternatives
		
		CFSocketSignature currentSocketSignature = {
			.protocolFamily = ((const struct sockaddr *)CFDataGetBytePtr((CFDataRef)currentAddrData))->sa_family,
			.socketType = type.socketType,
			.protocol = type.protocol,
			.address = (CFDataRef)currentAddrData,
		};
		
		AFSocket *socket = [[AFSocket alloc] initWithSignature:&currentSocketSignature callbacks:kCFSocketAcceptCallBack delegate:server];
		if (socket == nil) continue;
		
		[socket scheduleInRunLoop:CFRunLoopGetCurrent() forMode:kCFRunLoopDefaultMode];
		
		if (*port == 0) {
			// Note: extract the *actual* port used and use that for future allocations
			CFDataRef actualAddrData = CFSocketCopyAddress((CFSocketRef)[socket lowerLayer]);
			*port = ntohs(((struct sockaddr_in *)CFDataGetBytePtr(actualAddrData))->sin_port);
			// Note #warning explicit cast to sockaddr_in, this *will* work for both IPv4 and IPv6 as the port is in the same location, however investigate alternatives
			CFRelease(actualAddrData);
		}
		
		[server.hosts addConnectionsObject:socket];
		[socket open];
		
		[socket release];
	}
	
	return server;
}

+ (id)networkServerWithPort:(SInt32 *)port type:(struct AFSocketType)type {
	CFMutableArrayRef addresses = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	
	struct ifaddrs *addrs = NULL;
	int error = getifaddrs(&addrs);
	if (error != 0) return nil;
	
	struct ifaddrs *currentAddr = addrs;
	for (; currentAddr != NULL; currentAddr = currentAddr->ifa_next) {
		if (currentAddr->ifa_addr->sa_family == AF_LINK) continue;
		
		CFDataRef addrData = CFDataCreate(kCFAllocatorDefault, (void *)currentAddr->ifa_addr, currentAddr->ifa_addr->sa_len);
		CFArrayInsertValueAtIndex(addresses, 0, addrData);
		CFRelease(addrData);
	}
	
	AFConnectionServer *server = [self _serverWithPort:port socketType:type addresses:addresses];
	
	CFRelease(addresses);
	freeifaddrs(addrs);
	
	return server;
}

+ (id)localhostServerWithPort:(SInt32 *)port type:(struct AFSocketType)type {
	CFHostRef localhost = CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)@"localhost");
	
	CFStreamError error;
	memset(&error, 0, sizeof(CFStreamError));
	
	Boolean resolved = CFHostStartInfoResolution(localhost, (CFHostInfoType)kCFHostAddresses, &error);
	if (!resolved) return nil;
	
	return [self _serverWithPort:port socketType:type addresses:CFHostGetAddressing(localhost, NULL)];
}

+ (Class)connectionClass {
	[self doesNotRecognizeSelector:_cmd];
	return Nil;
}

- (id)init {
	[super init];
	
	hosts = [[AFConnectionPool alloc] init];
	[hosts addObserver:self forKeyPath:@"connections" options:(NSKeyValueObservingOptionNew) context:&ServerHostConnectionsPropertyObservationContext];
	
	clients = [[AFConnectionPool alloc] init];
	
	return self;
}

- (void)finalize {
	[self.clients disconnect];
	
	[super finalize];
}

- (void)dealloc {
	[self finalize];
	
	[clients release];
	
	[hosts removeObserver:self forKeyPath:@"connections"];
	[hosts disconnect];
	
	[hosts release];
	
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &ServerHostConnectionsPropertyObservationContext) {
		if (![[change objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue] == NSKeyValueChangeInsertion) return;
		
		[[change valueForKey:NSKeyValueChangeNewKey] makeObjectsPerformSelector:@selector(setDelegate:) withObject:self];
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (id <AFConnectionLayer>)newApplicationLayerForNetworkLayer:(id <AFConnectionLayer>)newLayer {
	Class connectionClass = [[self class] connectionClass];
	id <AFConnectionLayer> newApplicationLayer = [[[connectionClass alloc] initWithLowerLayer:newLayer delegate:self] autorelease];
	return newApplicationLayer;
}

- (void)layer:(id <AFConnectionLayer>)layer didAcceptConnection:(id <AFConnectionLayer>)newLayer {
	AFSocket *newSocket = newLayer;
	CFSocketSetSocketFlags((CFSocketRef)[newSocket lowerLayer], CFSocketGetSocketFlags((CFSocketRef)[newSocket lowerLayer]) & ~kCFSocketCloseOnInvalidate);
	
	id <AFConnectionLayer> newConnection = [self newApplicationLayerForNetworkLayer:newLayer];
	[self.clients addConnectionsObject:newConnection];
	
	[newConnection scheduleInRunLoop:CFRunLoopGetCurrent() forMode:kCFRunLoopDefaultMode];
	[newConnection open];
}

- (void)layer:(id <AFConnectionLayer>)socket didConnectToPeer:(const CFHostRef)host {
	if ([self.delegate respondsToSelector:@selector(layer:didAcceptConnection:)])
		[self.delegate layer:self didAcceptConnection:socket];
}

- (void)layerDidClose:(id <AFConnectionLayer>)layer {
	if (![self.clients.connections containsObject:layer]) return;
	
	[self.clients removeConnectionsObject:layer];
}

@end
