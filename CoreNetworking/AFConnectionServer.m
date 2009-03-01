//
//  ANServer.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnectionServer.h"

#import "AFSocketStreams.h"

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
	
	serverSockets = [[AFConnectionPool alloc] init];
	
	clientSockets = [[AFConnectionPool alloc] init];
	clientApplications = [[AFConnectionPool alloc] init];
	
	return self;
}

- (id)initWithSockets:(NSSet *)sockets {
	[self init];
	
	[[self mutableSetValueForKeyPath:@"serverSockets"] unionSet:sockets];
	
	return self;
}

- (void)dealloc {
#ifdef __OBJC_GC__
#error this class isn't GC compatible
#endif
	
	[self disconnectClients]; // Note: this isn't GC compatible, investigate further. Just do it in -finalize?
	[clientApplications release];
	[clientSockets release];
	
	[serverSockets disconnect];
	[serverSockets release];
	
	[super dealloc];
}

- (void)addServerSocketsObject:(id <AFConnectionLayer>)layer; {
	layer.hostDelegate = self;
	
	[serverSockets addConnectionsObject:layer];
}

- (void)removeServerSocketsObject:(id <AFConnectionLayer>)layer; {
	[serverSockets removeConnectionsObject:layer];
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

- (void)layer:(id <AFConnectionLayer>)socket didConnectToHost:(const struct sockaddr *)host {
#warning this callback should use CFHost
	
	@try {
		id <AFConnectionLayer> applicationLayer = [self newApplicationLayerForNetworkLayer:socket];
		
		if ([self.delegate respondsToSelector:@selector(server:shouldConnect:toHost:)]) {
#warning this callback should use CFHost
			BOOL continueConnecting = [self.delegate server:self shouldConnect:applicationLayer toHost:host];
			
			if (!continueConnecting) {
				if ([socket conformsToProtocol:@protocol(AFConnectionLayer)]) {
					[(id <AFConnectionLayer>)socket disconnect];
				}
				
				return;
			}
		}
		
		if ([applicationLayer conformsToProtocol:@protocol(AFConnectionLayer)]) {
			[applicationLayer connect];
		}
		
		[self.clientApplications addConnectionsObject:applicationLayer];
	}
	@finally {
		[clientSockets removeConnectionsObject:socket];
	}
}

- (void)layerDidConnect:(id <AFConnectionLayer>)layer {
	
}

- (void)layerDidDisconnect:(id <AFConnectionLayer>)layer {
	if ([self.clientApplications.connections containsObject:layer]) {
		[self.clientApplications removeConnectionsObject:layer];
	}
}

- (void)disconnectClients {
	[clientSockets disconnect];
	[clientApplications disconnect];
}

@end
