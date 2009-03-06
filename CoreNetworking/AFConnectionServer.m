//
//  ANServer.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnectionServer.h"

#import "AFSocket.h"

#import "AFConnectionPool.h"

@implementation AFConnectionServer

@synthesize delegate=_delegate;
@synthesize clientApplications;

+ (id)networkServer {
	[self doesNotRecognizeSelector:_cmd];
}

+ (id)localhostServer {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
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

- (void)dealloc {
#ifdef __OBJC_GC__
#error this class isn't GC compatible
#endif
	
	[self disconnectClients]; // Note: this isn't GC compatible, investigate further. Just do it in -finalize?
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
