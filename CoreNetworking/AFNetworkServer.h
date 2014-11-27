//
//  AFConnectionServer.h
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetwork-Types.h"
#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkSocket;
@class AFNetworkSchedule;
@class AFNetworkServer;

/*!
	\brief
	The server should consult the delegate for conditional operations. If your
	subclass provides a delegate protocol, it should conform to this one.
 */
@protocol AFNetworkServerDelegate <NSObject>

 @optional

/*
	\brief
	Sent to determine whether a connection should be permitted.

	\details
	This is sent before the first layer is encapsulated.

	\return
	Return NO to deny connectivity.
 */
- (BOOL)networkServer:(AFNetworkServer *)server shouldAcceptConnection:(id <AFNetworkTransportLayer>)connection;

/*!
	\brief
	Sent if the connection is accepted after consulting the delegate's
	-networkServer:shouldAcceptConnection: method.
 */
- (void)networkServer:(AFNetworkServer *)server didAcceptConnection:(id <AFNetworkTransportLayer>)connection;

/*!
	\brief
	Sent after each layer is encapsulated; before it is opened.
 */
- (void)networkServer:(AFNetworkServer *)server didEncapsulateLayer:(id <AFNetworkTransportLayer>)connection;

@end

/*!
	\brief
	This is a generic construct for spawning new client layers.
	
	\details
	After instantiating the server you can use one of the convenience methods to
	open socket(s).
 */
@interface AFNetworkServer : NSObject <AFNetworkServerDelegate> {
 @private
	AFNetworkSchedule *_schedule;
	
	id <AFNetworkServerDelegate> _delegate;
	
	NSMutableSet *_listeners;
	
	NSArray *_encapsulationClasses;
	NSMutableSet *_connections;
}

/*
	Initialization
 */

/*!
	\brief
	Designated constructor.
	
	\details
	Should be overridden to call the designated initialiser with an appropriate
	encapsulation class.
	
	By default this creates a server with `AFNetworkTransport` as the
	encapsulation class, i.e. a TCP server.
 */
+ (id)server;

/*!
	\brief
	Designated initialiser.

	\param clientClass
	The top level application layer class to represent connected clients.
 */
- (id)initWithEncapsulationClass:(Class)clientClass;

/*
	State
 */

/*!
	\brief
	Used to schedule each new network layer.
	
	\details
	A default schedule is created in `-init` targeting the global concurrent
	queue. This should be replaced before opening sockets if needed.
 */
@property (retain, nonatomic) AFNetworkSchedule *schedule;

/*!
	\brief
	The delegate is optional in this class, most servers should function without
	one.
 */
@property (assign, nonatomic) id <AFNetworkServerDelegate> delegate;

/*
	Socket Opening
 */

/*!
	\brief
	Defines the scope of the listening sockets.

	LocalOnly sockets can only be used from the local host.
	Global sockets MAY be globally accessible, and MUST be treated as globally
	accessible from a security perspective.
	
	Global scope socket addresses are IP wildcard and are capable of receiving
	data from any host.

	A number of factors will contribute to whether Global scope sockets are
	actually globally accessible:
	
	- Your host may have an interface with a globally routable address.
		- Though a firewall may drop packets addressed to your port before they
		  reach your process.

	- You might have a non-globally routable address, such as an address in the
	  private use ranges.
		- But there may be a statically configured NAT port mapping making your
		  port accessible.
		- But there may be a dynamically configured NAT port mapping.
			- An attacker may maliciously create a dynamic NAT port mapping.
			- You may have received an address from a DHCP server, the previous
			  owner of which may have constructed a dynamic port mapping
	
	Also consider that your host may be on a network with IPv4 NAT, but globally
	routable IPv6, sockets are opened for all address families to be IP protocol
	agnostic.

	Remember that NAT is not a firewall, if you don't want to receive data from
	hosts other than the local host, don't use Global scope.
 */
typedef AFNETWORK_ENUM(NSUInteger, AFNetworkInternetSocketScope) {
	AFNetworkInternetSocketScopeLocalOnly,
	AFNetworkInternetSocketScopeGlobal,
};

/*!
	\brief
	Open IP address family sockets scoped to the given scope. See
	`openInternetSocketsWithSocketSignature:socketAddresses:errorHandler:` for
	more information.

	\param scope
	AFNetworkInternetSocketScopeLocalOnly opens sockets using the localhost
	addresses.
	AFNetworkInternetSocketScopeGlobal opens sockets using wildcard addresses.

	\param port
	Transport layer port, can pass 0 to have an address chosen by the system.
 */
- (BOOL)openInternetSocketsWithSocketSignature:(AFNetworkSocketSignature const)socketSignature scope:(AFNetworkInternetSocketScope)scope port:(uint16_t)port errorHandler:(BOOL (^)(NSData *, NSError *))errorHandler;

/*!
	\brief
	Open IP address family sockets scoped to an address list.

	\details
	There is intentionally no port parameter, you must provide fully populated
	socket addresses.

	Use getaddrinfo to be IP address family agnostic and avoid hard coding
	address families in userspace.
	
	If any of the socket addresses cannot be opened -

	- if no errorHandler parameter is provided, all sockets opened by the
	  current message are closed and NO is returned.
	- if an errorHandler parameter is provided it will be called with the error
		- if the errorHandler returns NO, all sockets opened by the current
		  message are closed and NO is returned.
		- if the errorHandler returns YES, the enumeration continues.
	
	\return
	NO if any of the sockets couldn't be created (in which case this method is
	idempotent), YES if all sockets were successfully created.
 */
- (BOOL)openInternetSocketsWithSocketSignature:(AFNetworkSocketSignature const)socketSignature socketAddresses:(NSSet *)socketAddresses errorHandler:(BOOL (^)(NSData *, NSError *))errorHandler;

/*!
	\brief
	Opens a UNIX socket at the specified path.
	
	\details
	Makes no provisions for deleting an existing socket in the file system
	should it exist, and will fail if one does.
	
	\param location
	Only file scheme URLs are supported, an exception is thrown if you provide
	another scheme.
	
	\return
	YES if the socket was created, NO otherwise.
 */
- (BOOL)openPathSocketWithLocation:(NSURL *)location error:(NSError **)errorRef;

/*
 
 */

/*!
	\brief
	This is a funnel method, all the socket opening methods call this one.

	\details
	Rarely applicable to higher-level servers, sockets are opened on the lowest
	layer of the stack.
 */
- (AFNetworkSocket *)openSocketWithSignature:(AFNetworkSocketSignature const)signature address:(NSData *)address options:(NSSet *)options error:(NSError **)errorRef;

/*!
	\brief
	Called by `-openSocketWithSignature:address:error:` can be used to add
	externally configured listen sockets such as those inherited from launchd or
	retrieved from another bootstrap server.
 */
- (BOOL)addListenSocket:(AFNetworkSocket *)socket error:(NSError **)errorRef;

/*!
	\brief
	Close all listen sockets
 */
- (void)closeListenSockets;

/*
 
 */

/*!
	\brief
	Track an externally created connection, kept alive until it closes.
 */
- (void)addConnection:(id)connection;

/*!
	\brief
	Close all previously received connections.
	
	If the server is shutting down, listen sockets should be closed first.
 */
- (void)closeConnections;

/*
 
 */

/*!
	\brief
	Close all listen sockets and connected clients.
 */
- (void)close;

/*
	Delegate
	
	Overrides must call super.
 */

- (void)networkLayerDidOpen:(id <AFNetworkTransportLayer>)layer;
- (void)networkLayerDidClose:(id <AFNetworkTransportLayer>)layer;

/*
	Subclass hooks
 */

/*!
	\brief
	Sent for each layer constructed from the listeners before the stack is sent
	`-open`.
	
	Overrides must call super, the default implementation schedules the layer in
	the server environment using `scheduler`.
	
	\details
	Preferred set up point over `-networkLayer:didOpen:` which is messaged by the
	listen layer sockets too.
	
	\param layer
	An instance of your server `clientClass`
 */
- (void)configureLayer:(id)layer;

@end
