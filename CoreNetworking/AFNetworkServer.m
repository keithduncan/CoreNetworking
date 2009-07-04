//
//  AFConnectionServer.m
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFNetworkServer.h"

#import <sys/socket.h>
#import <sys/un.h>
#import <arpa/inet.h>
#import <objc/runtime.h>
#import "AmberFoundation/AmberFoundation.h"

#import "AFNetworkSocket.h"
#import "AFNetworkTransport.h"

#import	"AFNetworkTypes.h"
#import "AFNetworkFunctions.h"
#import "AFNetworkPool.h"

// Note: import this header last, allowing for any of the previous headers to import <net/if.h> see the getifaddrs man page for details
#import <ifaddrs.h>

static NSString *AFNetworkServerHostConnectionsPropertyObservationContext = @"ServerHostConnectionsPropertyObservationContext";

@interface AFNetworkServer () <AFConnectionLayerControlDelegate>
@property (readwrite, assign) Class clientClass;
@end

@implementation AFNetworkServer

@synthesize lowerLayer=_lowerLayer, delegate=_delegate;

@synthesize clients=_clients;
@synthesize clientClass=_clientClass;

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
	return [[[self alloc] initWithLowerLayer:[[[AFNetworkServer alloc] initWithLowerLayer:nil encapsulationClass:[AFNetworkSocket class]] autorelease] encapsulationClass:[AFNetworkTransport class]] autorelease];
}

- (id)initWithLowerLayer:(AFNetworkServer *)server {
	self = [self init];
	if (self == nil) return nil;
	
	_lowerLayer = [server retain];
	_lowerLayer.delegate = self;
	
	return self;
}

- (id)initWithLowerLayer:(AFNetworkServer *)server encapsulationClass:(Class)clientClass {
	self = [self initWithLowerLayer:(id)server];
	if (self == nil) return nil;
	
	_clients = [[AFNetworkPool alloc] init];
	[_clients addObserver:self forKeyPath:@"connections" options:(NSKeyValueObservingOptionNew) context:&AFNetworkServerHostConnectionsPropertyObservationContext];
	
	_clientClass = clientClass;
	
	return self;
}

- (void)finalize {
	[_clients close];
	
	[super finalize];
}

- (void)dealloc {
	[_lowerLayer release];
	
	[_clients close];
	
	[_clients removeObserver:self forKeyPath:@"connections"];
	[_clients release];
	
	[super dealloc];
}

- (id)forwardingTargetForSelector:(SEL)selector {
	return self.lowerLayer;
}

- (BOOL)respondsToSelector:(SEL)selector {
	return ([super respondsToSelector:selector] || [[self forwardingTargetForSelector:selector] respondsToSelector:selector]);
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

- (BOOL)openInternetSocketsWithTransportSignature:(AFInternetTransportSignature *)signature addresses:(NSSet *)sockaddrs {
	return [self openInternetSocketsWithSocketSignature:signature->type port:&signature->port addresses:sockaddrs];
}
	
- (BOOL)openInternetSocketsWithSocketSignature:(const AFSocketSignature *)signature port:(SInt32 *)port addresses:(NSSet *)sockaddrs {
	BOOL completeSuccess = YES;
	
	for (NSData *currentAddress in sockaddrs) {
		currentAddress = [[currentAddress mutableCopy] autorelease];
		
//#warning explicit cast to sockaddr_in, this *will* work for both IPv4 and IPv6 as the port is in the same location, however investigate alternatives
		((struct sockaddr_in *)CFDataGetMutableBytePtr((CFMutableDataRef)currentAddress))->sin_port = htons(*port);
		
		AFNetworkSocket *socket = [self openSocketWithSignature:signature address:currentAddress];
		
		if (socket == nil) {
			completeSuccess = NO;
			continue;
		}
		
		// Note: get the port after setting the address i.e. opening
		if (*port == 0) {
			// Note: extract the *actual* port used and use that for future sockets
			CFHostRef addressPeer = (CFHostRef)[socket peer];
			CFDataRef actualAddress = CFArrayGetValueAtIndex(CFHostGetAddressing(addressPeer, NULL), 0);
			*port = ntohs(((struct sockaddr_in *)CFDataGetBytePtr(actualAddress))->sin_port);
		}
	}
	
	return completeSuccess;
}

- (BOOL)openPathSocketWithLocation:(NSURL *)location {
	if (![location isFileURL]) {
		[NSException raise:NSInvalidArgumentException format:@"%s, (%@) is not a file: scheme URL", __PRETTY_FUNCTION__, location, nil];
		return NO;
	}
	
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
	AFNetworkServer *lowestLayer = self;
	while (lowestLayer.lowerLayer != nil) lowestLayer = lowestLayer.lowerLayer;
	self = lowestLayer;
	
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
	
	[self.clients addConnectionsObject:socket];
	return ([socket open]) ? socket : nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &AFNetworkServerHostConnectionsPropertyObservationContext) {
		if (![[change objectForKey:NSKeyValueChangeKindKey] unsignedIntegerValue] == NSKeyValueChangeInsertion) return;
		
		[[change valueForKey:NSKeyValueChangeNewKey] makeObjectsPerformSelector:@selector(setDelegate:) withObject:self];
	} else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (id <AFConnectionLayer>)newApplicationLayerForNetworkLayer:(id <AFConnectionLayer>)newLayer {
	id <AFConnectionLayer> connection = [[[self clientClass] alloc] initWithLowerLayer:newLayer];
	return connection;
}

- (BOOL)server:(AFNetworkServer *)server shouldAcceptConnection:(id <AFConnectionLayer>)connection fromHost:(const CFHostRef)host {
	return YES; // the default implementation has no reason to turn anyone away
}

- (void)layer:(id)layer didAcceptConnection:(id <AFConnectionLayer>)newLayer {
	if ([self.clients.connections containsObject:layer]) {
		[self.delegate layer:self didAcceptConnection:newLayer];
		return;
	}
	
	if ([self.delegate respondsToSelector:@selector(server:shouldAcceptConnection:fromHost:)]) {
		// Note: for accepted sockets, the peer will always be a CFHostRef
		CFHostRef host = (CFHostRef)[(id)newLayer peer];
		
		if (![self.delegate server:self shouldAcceptConnection:newLayer fromHost:host]) return;
	}
	
	id <AFConnectionLayer> newConnection = [[self newApplicationLayerForNetworkLayer:newLayer] autorelease];
	
	[self.clients addConnectionsObject:newConnection];
	[newConnection open];
}

- (void)layerDidOpen:(id <AFTransportLayer>)layer {
	if (![self.clients.connections containsObject:layer]) return;
	if (self.lowerLayer == nil) return;
	
	if ([self.delegate respondsToSelector:@selector(layer:didAcceptConnection:)])
		[self.delegate layer:self didAcceptConnection:layer];
}

- (void)layerDidClose:(id <AFConnectionLayer>)layer {
	if (![self.clients.connections containsObject:layer]) return;
	
	if (self.lowerLayer != nil) {
		id <AFTransportLayer> lowerLayer = [layer lowerLayer];
		lowerLayer.delegate = (id)self.lowerLayer;
		[lowerLayer close];
	}
	
	[self.clients removeConnectionsObject:layer];
}

@end
