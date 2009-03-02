//
//  ANServer.h
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/CoreNetworking.h"

@class AFConnectionPool;

@protocol AFConnectionLayer;
@protocol AFConnectionServerDelegate, AFConnectionLayerHostDelegate;

@interface AFConnectionServer : NSObject <AFConnectionLayerHostDelegate> {
	id <AFConnectionServerDelegate> _delegate;
	
	AFConnectionPool *serverSockets;
	
	AFConnectionPool *clientSockets;
	AFConnectionPool *clientApplications;
}

// Note:
//	the +networkServer: is accessable on all assigned IP addresses (it opens the equivalent of 0.0.0.0)
//	the +localhostServer: is only accessable on the loopback IPs and will be inaccessable to other hosts

+ (id)networkServer:(SInt32)port;
+ (id)localhostServer:(SInt32)port;

// Note: this is sent [[connectionClass alloc] init] to create a new application layer. It MUST be overridden in a subclass, calling the superclass implementation will throw an exception
+ (Class)connectionClass;

// Note: the server sets the socket delegate to self, expects sockets to implement <AFConnectionLayer>
- (id)initWithSockets:(NSSet *)sockets;

- (void)addServerSocketsObject:(id <AFConnectionLayer>)layer;
- (void)removeServerSocketsObject:(id <AFConnectionLayer>)layer;

// Note: not required, the server should operate without a delegate
@property (assign) id <AFConnectionServerDelegate> delegate;

- (id <AFConnectionLayer>)newApplicationLayerForNetworkLayer:(id <AFConnectionLayer>)socket; // Note: override point, if you need to customize your application layer before it is added to the connection pool, call super for basic setup first

@property (readonly, retain) AFConnectionPool *clientApplications;

// Note: don't disconnect the -clientApplications pool above, instead call this method which also disconnects the -clientSockets which don't yet have an application layer
- (void)disconnectClients;

@end

@protocol AFConnectionServerDelegate <NSObject>
 @optional
- (BOOL)server:(AFConnectionServer *)server shouldConnect:(id <AFConnectionLayer>)connection toHost:(const struct sockaddr *)addr;
@end
