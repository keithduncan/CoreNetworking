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

#import "AFSocketPort.h"

#import "AFConnectionPool.h"

// Note: import this header last, allowing for any of the previous headers to import <net/if.h>
// Note: see the man page for getifaddrs
#import <ifaddrs.h>

@implementation AFConnectionServer

@synthesize delegate=_delegate;
@synthesize clientApplications;

+ (id)_serverWithPort:(SInt32 *)port socketType:(struct AFSocketType)type addresses:(CFArrayRef)addrs {
#warning this methods should also configure the server to listen for IP-layer changes
	AFConnectionServer *server = [[[self alloc] init] autorelease];
	
	for (NSData *currentAddrData in (NSArray *)addrs) {
		struct sockaddr *currentAddr = alloca([currentAddrData length]);
		[currentAddrData getBytes:currentAddr length:[currentAddrData length]];
		
		((struct sockaddr_in *)currentAddr)->sin_port = *port;
#warning explicit cast to sockaddr_in, this *will* work for both IPv4 and IPv6 as the port is in the same location, however investigate alternatives
		
		CFSocketSignature currentSocketSignature = {
			.protocolFamily = currentAddr->sa_family,
			.socketType = type.socketType,
			.protocol = type.protocol,
			.address = (CFDataRef)currentAddrData,
		};
		
		AFSocket *socket = [[AFSocketPort alloc] initWithSignature:&currentSocketSignature delegate:server];
		if (socket == nil) continue;
		
		if (*port == 0) {
			// Note: extract the *actual* port used and use that for future allocations
			CFDataRef actualAddrData = CFSocketCopyAddress([socket lowerLayer]);
			*port = ((struct sockaddr_in *)CFDataGetBytePtr(actualAddrData))->sin_port;
#warning explicit cast to sockaddr_in, this *will* work for both IPv4 and IPv6 as the port is in the same location, however investigate alternatives
			CFRelease(actualAddrData);
		}
		
		[server addHostSocketsObject:socket];
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
	
	hostSockets = [[AFConnectionPool alloc] init];
	
	clientSockets = [[AFConnectionPool alloc] init];
	clientApplications = [[AFConnectionPool alloc] init];
	
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
	layer.delegate = self;
	
	[hostSockets addConnectionsObject:layer];
}

- (void)removeHostSocketsObject:(id <AFConnectionLayer>)layer; {
	layer.delegate = nil;
	
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
