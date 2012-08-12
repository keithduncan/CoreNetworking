//
//  AFConnectionServer.h
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetworkConnectionLayer.h"

#import "CoreNetworking/AFNetwork-Types.h"
#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkSocket;
@class AFNetworkPool;
@class AFNetworkSchedulerProxy;
@class AFNetworkServer;

/*!
	\brief
	The server should consult the delegate for conditional operations. If your subclass provides a delegate protocol, it should conform to this one.
 */
@protocol AFNetworkServerDelegate <AFNetworkConnectionLayerHostDelegate>

 @optional

/*
	\brief
	You can return NO to deny connectivity.
	
	\details
	This is sent before the first layer is encapsulated.
 */
- (BOOL)networkServer:(AFNetworkServer *)server shouldAcceptConnection:(id <AFNetworkConnectionLayer>)connection;

/*!
	\brief
	Sent if the connection is accepted after consulting the delegate's -networkServer:shouldAcceptConnection: method
 */
- (void)networkServer:(AFNetworkServer *)server didAcceptConnection:(id <AFNetworkConnectionLayer>)connection;

/*!
	\brief
	This is sent after each layer is encapsulated; before it is opened.
 */
- (void)networkServer:(AFNetworkServer *)server didEncapsulateLayer:(id <AFNetworkConnectionLayer>)connection;

@end


/*!
	\brief
	This is a generic construct for spawning new client layers.
	
	\details
	After instantiating the server you can use one of the convenience methods to open socket(s)
 */
@interface AFNetworkServer : NSObject <AFNetworkServerDelegate, AFNetworkConnectionLayerHostDelegate> {
 @private
	AFNetworkSchedulerProxy *_scheduler;
	
	id <AFNetworkServerDelegate> _delegate;
	
	NSArray *_encapsulationClasses;
	NSArray *_clientPools;
}

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
	Used to schedule each new network layer.
	
	\details
	A default scheduler is created in `-init` targeting the global concurrent queue, this can be replaced.
 */
@property (retain, nonatomic) AFNetworkSchedulerProxy *scheduler;

/*!
	\brief
	The delegate is optional in this class, most servers should function without one
 */
@property (assign, nonatomic) id <AFNetworkServerDelegate> delegate;

/*
	Socket Opening
 */

typedef AFNETWORK_OPTIONS(NSUInteger, AFNetworkInternetSocketScope) {
	AFNetworkInternetSocketScopeLocalOnly = 1UL << 0,
	AFNetworkInternetSocketScopeGlobal = 1UL << 1,
};
/*!
	\brief
	Provides a socket address construction API and calls -openInternetSocketsWithSocketSignature:socketAddresses:errorHandler:, see its documentation for more information.
	
	\param scope
	AFNetworkInternetSocketScopeLocalOnly opens sockets using the localhost addresses
	AFNetworkInternetSocketScopeGlobal opens sockets using wildcard addresses
	
	\param port
	Transport layer port, can pass 0 to have an address chosen by the system
 */
- (BOOL)openInternetSocketsWithSocketSignature:(const AFNetworkSocketSignature)socketSignature scope:(AFNetworkInternetSocketScope)scope port:(uint16_t)port errorHandler:(BOOL (^)(NSData *, NSError *))errorHandler;

/*!
	\brief
	This method is for opening IP address family sockets scoped to an address list.
	
	\details
	There is intentionally no port parameter, you must provide fully populated socket addresses.
	Use getaddrinfo to be IP address family agnostic and avoid hard coding address families in the userspace.
	
	If any of the socket addresses cannot be opened -
	- if no errorHandler parameter is provided, all sockets opened by the current message are closed and NO is returned
	- if an errorHandler parameter is provided it will be called with the error
	- - if the errorHandler returns NO, all sockets opened by the current message are closed and NO is returned
	- - if the errorHandler returns YES, the enumeration continues
	
	\return
	NO if any of the sockets couldn't be created (in which case this method is idempotent), YES if all sockets were successfully created
 */
- (BOOL)openInternetSocketsWithSocketSignature:(const AFNetworkSocketSignature)socketSignature socketAddresses:(NSSet *)socketAddresses errorHandler:(BOOL (^)(NSData *, NSError *))errorHandler;

/*!
	\brief
	This method opens a UNIX socket at the specified path.
	
	\details
	This method makes no provisions for deleting an existing socket should it exist, and will fail if one does.
	
	\param location
	Only file:// URLs are supported, an exception is thrown if you provide another scheme.
	
	\return
	NO if the socket couldn't be created
 */
- (BOOL)openPathSocketWithLocation:(NSURL *)location error:(NSError **)errorRef;

/*
 
 */

/*!
	\brief
	This is a funnel method, all the socket opening methods call this one.
	
	\details
	This method is rarely applicable to higher-level servers, sockets are opened on the lowest layer of the stack.
 */
- (AFNetworkSocket *)openSocketWithSignature:(const AFNetworkSocketSignature)signature address:(NSData *)address error:(NSError **)errorRef;

/*
	Server Clients
 */

/*!
	\brief
	This method determines the class of the |layer| parameter and wraps it in the encapsulation class one higher than it.
	
	\details
	Override point, if you need to customize layers before they are added to their connection pool, call super for creation first.
 */
- (void)encapsulateNetworkLayer:(id <AFNetworkConnectionLayer>)layer;

/*!
	\brief
	The pools of interest are likely to be the lowest level at index 0 containing the AFNetworkSockets and the top most pool containing the top-level connection objects this server has created.
 */
@property (readonly, retain, nonatomic) NSArray *clientPools;

@end
