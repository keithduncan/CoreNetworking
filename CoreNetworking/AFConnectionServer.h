//
//  ANServer.h
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFSocket.h"
#import "CoreNetworking/AFConnectionLayer.h"

@class AFConnectionPool;

@protocol AFConnectionServerDelegate;

/*!
	@class
	@abstract	This is a generic construct for spawning new client layers.
	@discussion	After instantiating the server you can use one of the convenience methods to open a collection of sockets
 */
@interface AFConnectionServer : NSObject <AFConnectionLayerHostDelegate, AFSocketHostDelegate> {
	id <AFConnectionServerDelegate> _delegate;
	
	Class _clientClass;
	AFConnectionServer *_lowerLayer;
	
	AFConnectionPool *hosts, *clients;
}

/*!
	@method
	@abstract	Override Initialiser
	@discussion	A server should know how to create its own lower-layer, do so in this method
 */
- (id)init;

/*!
	@method
	@abstract	Designated Initialiser
 */
- (id)initWithLowerLayer:(AFConnectionServer *)server encapsulationClass:(Class)clientClass;

/*!
	@property
	@abstract	This class is used to instantiate a new higher-level layer when the server receives the <tt>-layer:didAcceptConnection:</tt> delegate callback
 */
@property (readonly, assign) Class clientClass;

/*!
	@property
	@abstract	This is the server that this one sits atop. The delegate of this object should be the upper server.
 */
@property (readonly, retain) AFConnectionServer *lowerLayer;

/*!
	@method
	@abstract	The delegate is optional in this class, most servers should function without one
 */
@property (assign) id <AFConnectionServerDelegate> delegate;

/*!
	@method
	@abstract	Create a server with ports open on all IP addresses (it equivalent of ::0)
	@discussion	This method is rarely applicable to higher-level servers, if you do not implement it, you MUST forward it to your lower layer
	@param		|port| is passed by reference so that if you pass 0 you get back the actual port
 */
- (id)openNetworkSockets:(SInt32 *)port withType:(struct AFSocketType)type;

/*!
	@method
	@abstract	Create a server with ports open on all IP addresses that @"localhost" resolves to (equivalent to ::1)
	@discussion	This method is rarely applicable to higher-level servers, if you do not implement it, you MUST forward it to your lower layer
				This is likely only to be useful for testing your server, since it won't be accessable from another computer
				This is a subset of the sockets opened in <tt>-openNetworkSockets:withType:</tt> and doesn't need to be used in addition to that method
 */
- (id)openLocalhostSockets:(SInt32 *)port withType:(struct AFSocketType)type;

/*!
	@property
	@abstract	You can add host sockets to this object, the server observes the |connections| property and sets itself as the delegate for any objects
	@discussion	The server expects <tt>-layer:didAcceptConnection:</tt> callbacks to spawn new layers, and subsequently spawn new application layers
 */
@property (readonly, retain) AFConnectionPool *hosts;

/*!
	@method
	@abstract	this method uses the <tt>+connectionClass</tt>
	@discussion	override point, if you need to customize your application layer before it is added to the connection pool, call super for creation and setup first
 */
- (id <AFConnectionLayer>)newApplicationLayerForNetworkLayer:(id <AFConnectionLayer>)socket;

/*!
	@property
 */
@property (readonly, retain) AFConnectionPool *clients;

@end

@protocol AFConnectionServerDelegate <AFConnectionLayerHostDelegate>
 @optional
- (BOOL)server:(AFConnectionServer *)server shouldConnect:(id <AFConnectionLayer>)connection toHost:(const CFHostRef)addr;
@end
