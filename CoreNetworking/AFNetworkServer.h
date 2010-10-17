//
//  AFConnectionServer.h
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetworkTypes.h"
#import "CoreNetworking/AFConnectionLayer.h"

@class AFNetworkSocket;
@class AFNetworkPool;
@class AFNetworkServer;

/*!
	\brief
	The server should consult the delegate for conditional operations. If your subclass provides a delegate protocol, it should conform to this one too.
 */
@protocol AFNetworkServerDelegate <AFConnectionLayerHostDelegate>

 @optional

/*
	\brief
	You can return FALSE to deny connectivity.
 
	\details
	This is sent before the first layer is encapsulated.
 */
- (BOOL)server:(AFNetworkServer *)server shouldAcceptConnection:(id <AFConnectionLayer>)connection;

/*!
	\brief
	This is sent after each layer is encapsulated; before it is opened.
 */
- (void)server:(AFNetworkServer *)server didEncapsulateLayer:(id <AFConnectionLayer>)connection;

@end


/*!
	\brief
	This is a generic construct for spawning new client layers.
	
	\details
	After instantiating the server you can use one of the convenience methods to open socket(s)
 */
@interface AFNetworkServer : NSObject <AFNetworkServerDelegate, AFConnectionLayerHostDelegate> {
 @private
	id <AFNetworkServerDelegate> _delegate;
	
	NSArray *_encapsulationClasses;
	NSArray *_clientPools;
}

/*
	Host Addresses
 */

/*!
	\details
	A collection of NSData objects containing either (struct sockaddr_in) or (struct sockaddr_in6), however you shouldn't <em>need</em> to know this.
	This is likely only to be useful for testing your server, since it won't be accessable from another computer.
 
	\return
	All the localhost socket addresses, these are only accessible from the local machine.
	This allows you to create a server with ports open on all IP addresses that @"localhost" resolves to (equivalent to 127.0.0.1 and ::1).
 */
+ (NSSet *)localhostInternetSocketAddresses;

/*!
	\details
	A collection of NSData objects containing either (struct sockaddr_in) or (struct sockaddr_in6).
	
	\return
	All the network socket addresses, these may be accessable from other network clients (ignoring firewall restrictions).
 */
+ (NSSet *)allInternetSocketAddresses;

/*
	Initialization
 */

/*!
	\brief
	Designated Constructor.
	
	\details
	This should call the designated initialiser with an appropriate encapsulation class. By default this creates a server with <tt>AFNetworkTransport</tt> as the encapsulation class.
 */
+ (id)server;

/*!
	\brief
	Designated Initialiser.
 */
- (id)initWithEncapsulationClass:(Class)clientClass;

/*
	State
 */

/*!
	\brief
	The delegate is optional in this class, most servers should function without one
 */
@property (assign) id <AFNetworkServerDelegate> delegate;

/*
	Socket Opening
 */

/*!
	\brief
	See <tt>-openInternetSocketsWithSocketSignature:port:addresses:</tt>.
 */
- (BOOL)openInternetSocketsWithTransportSignature:(const AFNetworkInternetTransportSignature)signature addresses:(NSSet *)sockaddrs;

/*!
	\brief
	This method will open IP sockets, the addresses passed in |sockaddrs| should be either (struct sockaddr_in) or (struct sockaddr_in6) or another future IP socket address, so long as there's a sixteen bit port number at an offset of (((uint8_t)(struct sockaddr_sa *))+16)
	
	\param port
	This is an in-out parameter, passing zero in by reference will have the kernel allocate a port number, the location you provide will contain that number on return
 
	\return
	NO if any of the sockets couldn't be created, this will be expanded in future to allow delegate interaction to determine failure.
 */
- (BOOL)openInternetSocketsWithSocketSignature:(const AFNetworkSocketSignature)signature port:(SInt32 *)port addresses:(NSSet *)sockaddrs;

/*!
	\brief
	This method opens a UNIX socket at the specified path.
	
	\details
	This method makes no provisions for deleting an existing socket should it exist, and will fail if one does.
	
	\param location
	Only file:// URLs are supported, an exception is thrown if you profide another scheme.
	
	\return
	NO if the socket couldn't be created
 */
- (BOOL)openPathSocketWithLocation:(NSURL *)location;

/*!
	\brief
	This is a funnel method, all the socket opening methods call this one.
	
	\details
	This method is rarely applicable to higher-level servers, sockets are opened on the lowest layer of the stack.
 */
- (AFNetworkSocket *)openSocketWithSignature:(const AFNetworkSocketSignature)signature address:(NSData *)address;

/*
	Server Clients
 */

/*!
	\brief
	This method determines the class of the |layer| parameter and wraps it in the encapsulation class one higher than it.
	
	\details
	Override point, if you need to customize layers before they are added to their connection pool, call super for creation first.
 */
- (void)encapsulateNetworkLayer:(id <AFConnectionLayer>)layer;

/*!
	\brief
	The pools of interest are likely to be the lowest level at index 0 containing the AFNetworkSockets and the top most pool containing the top-level connection objects this server has created.
 */
@property (readonly) NSArray *clientPools;

@end
