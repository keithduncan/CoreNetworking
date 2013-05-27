//
//  AFNetworkSocket.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFNetworkConnectionLayer.h"

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkSocket;
@class AFNetworkSchedule;
@class AFNetworkDatagram;

/*!
	\brief
	Delegates must implement the method appropriate for the socket type.
	SOCK_STREAM socket delegates must implement `-networkLayer:didReceiveConnection:`
	SOCK_DGRAM socket delegates must implement `-networkLayer:didReceiveDatagram:`
 */
@protocol AFNetworkSocketHostDelegate <NSObject>

 @optional

- (void)networkLayer:(AFNetworkSocket *)socket didReceiveConnection:(AFNetworkSocket *)connection;

- (void)networkLayer:(AFNetworkSocket *)socket didReceiveDatagram:(AFNetworkDatagram *)datagram;

@end

@protocol AFNetworkSocketDelegate <AFNetworkSocketHostDelegate>

- (void)networkLayerDidOpen:(AFNetworkSocket *)socket;

- (void)networkLayerDidClose:(AFNetworkSocket *)socket;

@end

/*!
	\brief
	Creates more `AFNetworkSocket` objects upon revieving inbound connections or datagrams.
 */
@interface AFNetworkSocket : AFNetworkLayer {
 @package
	CFSocketNativeHandle _socketNative;
	
 @private
	AFNETWORK_STRONG CFSocketSignature *_signature;
	NSSet *_options;
	
	NSUInteger _socketFlags;
	
	AFNetworkSchedule *_schedule;
	struct {
		struct {
			AFNETWORK_STRONG CFTypeRef _fileDescriptor;
			AFNETWORK_STRONG CFTypeRef _source;
		} _runLoop;
		void *_dispatchSource;
	} _sources;
}

/*!
	\brief
	Host Initialiser.
	`AFNetworkServer` uses this method for the addresses passed to its open methods.
	A socket is created with the given characteristics and the address is set/bound.
	
	\param options
	Options are set on the socket pre-bind() when opening
	
	\details
	If the socket cannot be created they return nil.
 */
- (id)initWithSocketSignature:(CFSocketSignature const *)signature options:(NSSet *)options;

/*!
	\brief
	Connect initialiser.
	Used to create new sockets for inbound connections or datagrams.
	
	\details
	Since AFNetworkSocket doesnt actually perform any read/write operations; this method doesn't take any options.
	This is intended to provide a socket to a higher layer.
 */
- (id)initWithNativeHandle:(CFSocketNativeHandle)handle;

/*!
	\brief
	SOCK_STREAM sockets will spawn additional connected layers
	SOCK_DGRAM sockets will spwan messages
 */
@property (assign, nonatomic) id <AFNetworkSocketDelegate> delegate;

/*!
	\brief
	Offers inline synchronous error reporting.
	
	\details
	Asserts that the delegate is appropriate for the socket type.
 */
- (BOOL)open:(NSError **)errorRef;

/*!
	\brief
	Close the underlying socket.
 */
- (void)close;

/*!
	\brief
	This returns the local socket address.
 */
@property (readonly, nonatomic) NSData *localAddress;

/*!
	\brief
	This returns the remote socket address.
	This is likely to be of most use when determining the reachbility of an endpoint.
 */
@property (readonly, nonatomic) NSData *peerAddress;

@end
