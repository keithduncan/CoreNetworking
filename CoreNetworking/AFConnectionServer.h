//
//  ANServer.h
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetworkTypes.h"
#import "CoreNetworking/AFConnectionLayer.h"

@class AFConnectionPool;
@class AFConnectionServer;


@protocol AFConnectionServerDelegate <AFConnectionLayerHostDelegate>
 @optional
- (BOOL)server:(AFConnectionServer *)server shouldAcceptConnection:(id <AFConnectionLayer>)connection fromHost:(const CFHostRef)host;
@end

/*!
	@brief	This is a generic construct for spawning new client layers.
	@detail	After instantiating the server you can use one of the convenience methods to open a collection of sockets
 */
@interface AFConnectionServer : AFNetworkLayer <AFConnectionServerDelegate, AFConnectionLayerHostDelegate> {	
	Class _clientClass;
	AFConnectionPool *hosts, *clients;
}

/*!
	@detail	A collection of NSData objects containing a (struct sockaddr *)
	@result	All the network socket addresses, these may be accessable from other network clients (ignoring firewalls).
 */
+ (NSSet *)networkSocketAddresses;

/*!
	@detail	A collection of NSData objects containing a (struct sockaddr *)
			This is likely only to be useful for testing your server, since it won't be accessable from another computer
	@result	All the localhost socket addresses, these are only accessible from the local machine.
			This allows you to create a server with ports open on all IP addresses that @"localhost" resolves to (equivalent to ::1).
 */
+ (NSSet *)localhostSocketAddresses;

/*!
	@brief	Override Constructor
	@detail	This should call the designated initialiser with an appropriate |lowerLayer| and encapsulation class.
			By default this creates a server with no |lowerLayer| and <tt>AFSocketTransport</tt> as the encapsulation class.
 */
+ (id)server;

/*!
	@brief	Designated Initialiser
 */
- (id)initWithLowerLayer:(AFConnectionServer *)server encapsulationClass:(Class)clientClass;

/*!
	@brief	The server that this one sits atop. The delegate of this object should be the upper-layer server.
 */
@property (readonly) AFConnectionServer *lowerLayer;

/*!
	@brief	The delegate is optional in this class, most servers should function without one
 */
@property (assign) id <AFConnectionServerDelegate> delegate;

/*!
	@brief	Shorthand for <tt>-openSockets:withType:addresses:</tt> where you already have an <tt>AFSocketTransportSignature</tt> preconfigured.
	@detail	See <tt>-openSockets:withType:addresses:</tt>
 */
- (void)openSockets:(const AFNetworkTransportSignature *)signature addresses:(NSSet *)sockAddrs;

/*!
	@brief	Opens an AFSocket for each address and schedules it on the current run-loop.
	@detail	This method is rarely applicable to higher-level servers, therefore this method contains 
			its own forwarding code (because all instances respond to it) and the sockets are opened
			on the lowest layer of the stack.
	@param	|port| is passed by reference so that if you pass 0 you get back the actual port
 */
- (void)openSockets:(SInt32 *)port withSignature:(const AFNetworkSocketSignature *)signature addresses:(NSSet *)sockAddrs;

/*!
	@brief	This class is used to instantiate a new higher-level layer when the server receives the <tt>-layer:didAcceptConnection:</tt> delegate callback
 */
@property (readonly, assign) Class clientClass;

/*!
	@brief	You can add host sockets to this object, the server observes the |connections| property and sets itself as the delegate for any objects
	@detail	The server expects <tt>-layer:didAcceptConnection:</tt> callbacks to spawn new layers, and subsequently spawn new application layers
 */
@property (readonly, retain) AFConnectionPool *hosts;

/*!
	@brief	this method uses the <tt>+connectionClass</tt>
	@detail	override point, if you need to customize your application layer before it is added to the connection pool, call super for creation and setup first
 */
- (id <AFConnectionLayer>)newApplicationLayerForNetworkLayer:(id <AFConnectionLayer>)socket;

@property (readonly, retain) AFConnectionPool *clients;

@end
