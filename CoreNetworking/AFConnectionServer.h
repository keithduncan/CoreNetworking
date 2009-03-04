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
	
	AFConnectionPool *hostSockets;
	
	AFConnectionPool *clientSockets;
	AFConnectionPool *clientApplications;
}

/*!
	@method
	@abstract	Create a server with ports open on all IP addresses (it equivalent of 0.0.0.0)
 */
+ (id)networkServer:(SInt32)port;

/*!
	@method
	@abstract	Create a server with ports open on all loopback IP addresses (the equivalent of 127.0.0.1)
 */
+ (id)localhostServer:(SInt32)port;

/*!
	@method
	@abstract	The returned object is sent [[connectionClass alloc] init] to create a new application layer.
					It MUST be overridden in a subclass, calling the superclass implementation will throw an exception
 */
+ (Class)connectionClass;

/*!
    @method     
    @abstract   the server sets the socket delegate to self, expects sockets to implement <AFConnectionLayer>
*/
- (id)initWithHostSockets:(NSSet *)sockets;

/*!
	@method
	@abstract	The delegate is optional in this class, most servers should function without one
 */
@property (assign) id <AFConnectionServerDelegate> delegate;

- (void)addHostSocketsObject:(id <AFConnectionLayer>)layer;
- (void)removeHostSocketsObject:(id <AFConnectionLayer>)layer;

- (id <AFConnectionLayer>)newApplicationLayerForNetworkLayer:(id <AFConnectionLayer>)socket; // Note: override point, if you need to customize your application layer before it is added to the connection pool, call super for basic setup first

@property (readonly, retain) AFConnectionPool *clientApplications;

// Note: don't disconnect the -clientApplications pool above, instead call this method which also disconnects the -clientSockets which don't yet have an application layer
- (void)disconnectClients;

@end

@protocol AFConnectionServerDelegate <NSObject>
 @optional
- (BOOL)server:(AFConnectionServer *)server shouldConnect:(id <AFConnectionLayer>)connection toHost:(const CFHostRef)addr;
@end
