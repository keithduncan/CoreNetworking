//
//  ANServer.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnectionServer.h"

#import <sys/socket.h>
#import <arpa/inet.h>

#import "AFSocket.h"

#import "AFConnectionPool.h"

// Note: import this header last, allowing for any of the previous headers to import <net/if.h>
// Note: see the man page for getifaddrs
#import <ifaddrs.h>

@implementation AFConnectionServer

@synthesize delegate=_delegate;
@synthesize clientApplications;

+ (id)_serverWithPort:(SInt32)port addresses:(CFArrayRef)addrs {
	NSMutableSet *sockets = [NSMutableSet setWithCapacity:CFArrayGetCount(addrs)];
	
	for (NSData *currentAddrData in (NSArray *)addrs) {
		const struct sockaddr *currentAddr = [currentAddrData bytes];
		
		CFSocketSignature currentSocketSignature = {
			.protocolFamily = currentAddr->sa_family,
			.socketType = SOCK_STREAM,
			.protocol = IPPROTO_TCP,
			.address = currentAddrData,
		};
		
		AFSocket *hostSocket = [AFSocket hostWithSignature:&currentSocketSignature];
		[sockets addObject:hostSocket];
	}
	
	return [[[self alloc] initWithHostSockets:sockets] autorelease];
}

#warning these methods should also configure the server to listen for IP-layer changes

+ (id)networkServer:(SInt32)port {
	CFMutableArrayRef addresses = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	
	struct ifaddrs *addrs = NULL;
	int error = getifaddrs(&addrs);
	if (error != 0) return nil;
	
	struct ifaddrs *currentAddr = addrs;
	for (; currentAddr != NULL; currentAddr = currentAddr->ifa_next) {
		if (currentAddr->ifa_addr->sa_family == AF_LINK) continue;
		
		CFDataRef addrData = CFDataCreate(kCFAllocatorDefault, currentAddr, currentAddr->ifa_addr->sa_len);
		CFArrayInsertValueAtIndex(addresses, 0, addrData);
		CFRelease(addrData);
	}
	
	freeifaddrs(addrs);
	
	AFConnectionServer *server = [self _serverWithPort:port addresses:addresses];
	
	CFRelease(addresses);
	
	return server;
}

+ (id)localhostServer:(SInt32)port {
	CFHostRef localhost = CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)@"localhost");
	
	CFStreamError error;
	memset(&error, 0, sizeof(CFStreamError));
	
	Boolean resolved = CFHostStartInfoResolution(localhost, (CFHostInfoType)kCFHostAddresses, &error);
	if (!resolved) return nil;
	
	return [self _serverWithPort:port addresses:CFHostGetAddressing(localhost, &resolved)];
}

+ (Class)connectionClass {
	[self doesNotRecognizeSelector:_cmd];
	return Nil;
}

- (id)init {
	[super init];
	
	hostSockets = [[AFConnectionPool alloc] init];
	
	clientSockets = [[AFConnectionPool alloc] init];
	clientApplications = [[AFConnectionPool alloc] init];
	
	return self;
}

- (id)initWithHostSockets:(NSSet *)sockets {
	[self init];
	
	[[self mutableSetValueForKeyPath:@"hostSockets"] unionSet:sockets];
	
	return self;
}

- (void)finalize {
	[self disconnectClients];
	
	[super finalize];
}

- (void)dealloc {
	[self finalize];
	
	[clientApplications release];
	[clientSockets release];
	
	[hostSockets disconnect];
	[hostSockets release];
	
	[super dealloc];
}

- (void)addHostSocketsObject:(id <AFConnectionLayer>)layer; {
	layer.hostDelegate = self;
	
	[hostSockets addConnectionsObject:layer];
}

- (void)removeHostSocketsObject:(id <AFConnectionLayer>)layer; {
	[hostSockets removeConnectionsObject:layer];
}

- (id <AFConnectionLayer>)newApplicationLayerForNetworkLayer:(id <AFConnectionLayer>)socket {
	Class connectionClass = [[self class] connectionClass];
	
	AFConnection <AFNetworkLayerDataDelegate> *layer = [[[connectionClass alloc] initWithDestination:nil] autorelease];
	layer.delegate = self;
	
	layer.lowerLayer = (id)socket;
	[socket setDelegate:(id)layer];
	
	return layer;
}

- (void)layer:(id <AFConnectionLayer>)socket didAcceptConnection:(id <AFConnectionLayer>)newSocket {
	[clientSockets addConnectionsObject:newSocket];
#warning check the flow control to make sure that it isn't kept around despite error, it is removed in the callback below
}

- (void)layerDidConnect:(id <AFConnectionLayer>)socket host:(const CFHostRef)host {
#warning this callback should use CFHost
	
	@try {
		id <AFConnectionLayer> applicationLayer = [self newApplicationLayerForNetworkLayer:socket];
		
		if ([self.delegate respondsToSelector:@selector(server:shouldConnect:toHost:)]) {
			BOOL continueConnecting = [self.delegate server:self shouldConnect:applicationLayer toHost:host];
			
			if (!continueConnecting) {
				if ([socket conformsToProtocol:@protocol(AFConnectionLayer)]) {
					[(id <AFConnectionLayer>)socket close];
				}
				
				return;
			}
		}
		
		[applicationLayer open];
		
		[self.clientApplications addConnectionsObject:applicationLayer];
	}
	@finally {
		[clientSockets removeConnectionsObject:socket];
	}
}

- (void)layerDidOpen:(id <AFConnectionLayer>)layer {
	
}

- (void)layerDidClose:(id <AFConnectionLayer>)layer {
	if ([self.clientApplications.connections containsObject:layer]) {
		[self.clientApplications removeConnectionsObject:layer];
	}
}

- (void)disconnectClients {
	[clientSockets disconnect];
	[clientApplications disconnect];
}

@end
