//
//  AFConnectionServer.h
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetworkTypes.h"
#import "CoreNetworking/AFConnectionLayer.h"

@class AFNetworkSocket;
@class AFNetworkPool;
@class AFNetworkServer;

@protocol AFNetworkServerDelegate <AFConnectionLayerHostDelegate>
 @optional
- (BOOL)server:(AFNetworkServer *)server shouldAcceptConnection:(id <AFConnectionLayer>)connection;
@end

/*!
	@brief
	This is a generic construct for spawning new client layers.
 
	@detail
	After instantiating the server you can use one of the convenience methods to open socket(s)
 */
@interface AFNetworkServer : NSObject <AFNetworkServerDelegate, AFConnectionLayerHostDelegate> {
	id <AFNetworkServerDelegate> _delegate;
	AFNetworkServer *_lowerLayer;
	
	AFNetworkPool *_clients;
	Class _clientClass;
}

/*!
	@detail
	A collection of NSData objects containing either (struct sockaddr_in) or (struct sockaddr_in6).
	
	@result
	All the network socket addresses, these may be accessable from other network clients (ignoring firewall restrictions).
 */
+ (NSSet *)allInternetSocketAddresses;

/*!
	@detail
	A collection of NSData objects containing either (struct sockaddr_in) or (struct sockaddr_in6), however you shouldn't <em>need</em> to know this.
	This is likely only to be useful for testing your server, since it won't be accessable from another computer.
	
	@result
	All the localhost socket addresses, these are only accessible from the local machine.
	This allows you to create a server with ports open on all IP addresses that @"localhost" resolves to (equivalent to 127.0.0.1 and ::1).
 */
+ (NSSet *)localhostInternetSocketAddresses;

/*!
	@brief
	Override Constructor
 
	@detail
	This should call the designated initialiser with an appropriate |lowerLayer| and encapsulation class.
	By default this creates a server with no |lowerLayer| and <tt>AFNetworkTransport</tt> as the encapsulation class.
 */
+ (id)server;

/*!
	@brief
	This method is called by the designated initialiser.
 */
- (id)initWithLowerLayer:(AFNetworkServer *)server;

/*!
	@brief
	Designated Initialiser.
 */
- (id)initWithLowerLayer:(AFNetworkServer *)server encapsulationClass:(Class)clientClass;

/*!
	@brief
	The server that this one sits atop. The lowerLayer delegate is set to this object.
 */
@property (readonly) AFNetworkServer *lowerLayer;

/*!
	@brief
	The delegate is optional in this class, most servers should function without one
 */
@property (assign) id <AFNetworkServerDelegate> delegate;

/*!
	@brief
	See <tt>-openInternetSocketsWithSocketSignature:port:addresses:</tt>.
 */
- (BOOL)openInternetSocketsWithTransportSignature:(const AFInternetTransportSignature *)signature addresses:(NSSet *)sockaddrs;

/*!
	@brief
	This method will open IP sockets, the addresses passed in |sockaddrs| should be either (struct sockaddr_in) or (struct sockaddr_in6) or another future IP socket address, so long as there's a sixteen bit port number at an offset of (((uint8_t)(struct sockaddr_sa *))+16)
	
	@param |port|
	This is an in-out parameter, passing zero in by reference will have the kernel allocate a port number, the location you provide will contain that number on return
 
	@result
	NO if any of the sockets couldn't be created, this will be expanded in future to allow delegate interaction to determine failure.
 */
- (BOOL)openInternetSocketsWithSocketSignature:(const AFSocketSignature *)signature port:(SInt32 *)port addresses:(NSSet *)sockaddrs;

/*!
	@brief
	This method opens a UNIX socket at the specified path.
 
	@detail
	This method makes no provisions for deleting an existing socket should it exist, and will fail if one does.
 
	@param |location|
	Only file:// URLs are supported.
 
	@result
	NO if the socket couldn't be created
 */
- (BOOL)openPathSocketWithLocation:(NSURL *)location;

/*!
	@brief
	This is the call-through method, all the other socket opening methods call down to this one.
 
	@detail
	This method is rarely applicable to higher-level servers, therefore this method contains 
	its own forwarding code (because all instances respond to it) and the sockets are opened
	on the lowest layer of the stack.
 */
- (AFNetworkSocket *)openSocketWithSignature:(const AFSocketSignature *)signature address:(NSData *)address;

/*!
	@brief
	This class is used to instantiate a new higher-level layer when the server receives the <tt>-layer:didAcceptConnection:</tt> delegate callback
 */
@property (readonly, assign) Class clientClass;

/*!
	@brief
	This method uses the <tt>+clientClass</tt>. This returns an object with +1 retain count, don't return an autoreleased object.
 
	@detail
	Override point, if you need to customize your application layer before it is added to the connection pool, call super for creation and setup first
 */
- (id <AFConnectionLayer>)newApplicationLayerForNetworkLayer:(id <AFConnectionLayer>)socket;

/*!
	@brief
	This pool contains the instantiated clientClass objects this server has created.
 */
@property (readonly, retain) AFNetworkPool *clients;

@end
