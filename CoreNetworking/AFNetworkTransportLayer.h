//
//  AFNetworkLayer.h
//  Bonjour
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkPacket.h"

/*
 *	Network Layers
 *	Transport + Internetwork
 */

@protocol AFNetworkTransportLayerHostDelegate;
@protocol AFNetworkTransportLayerControlDelegate;
@protocol AFNetworkTransportLayerDataDelegate;

#pragma mark -

/*!
	\brief
	An `AFNetworkTransportLayer` object should encapsulate data (as defined in
	IETF-RFC-1122 <http://tools.ietf.org/html/rfc1122>).
	
	\details
	A layer should pass data to it's superclass for further processing, the
	top-level superclass will pass the data to the lower layer. This creates a
	two dimensional chain allowing for maximum flexiblity.
*/
@protocol AFNetworkTransportLayer <NSObject>

/*!
	\brief
	Currently the control and data delegates share the same property.
 */
@property (assign, nonatomic) id <AFNetworkTransportLayerControlDelegate, AFNetworkTransportLayerDataDelegate> delegate;

/*!
	\brief
	Designated Initialiser.
	
	\details
	For the moment this is designed to be used for an inbound network communication initialisation chain, outbound initialisers have a more specific signatures.
 */
- (id)initWithLowerLayer:(id <AFNetworkTransportLayer>)layer;

/*!
	\brief
	Retrieve the lower layer.
 */
- (id <AFNetworkTransportLayer>)lowerLayer;

 @optional

/*!
	\brief
	The delegate callbacks will convey success or failure.
 */
- (void)open;

/*!
	\return
	YES if the layer is currently open, NO otherwise.
 */
- (BOOL)isOpen;

/*!
	\details
	A layer may elect to remain open, in which case you will not receive the
	-networkLayerDidClose: delegate callback until it actually closes.
 */
- (void)close;

/*!
	\brief
	Many layers are linear non-recurrant in nature, like a TCP stream; once
	closed it cannot be reopened.
 */
- (BOOL)isClosed;

 @required

/*!
	\brief
	Schedule a write to the network stack.
	
	\param buffer
	Can be an `NSData` or <AFNetworkPacketWriting> conforming object.

	The timeout and context of the packet will be set to the given values.
 */
- (void)performWrite:(id)buffer withTimeout:(NSTimeInterval)duration context:(void *)context;

/*!
	\brief
	Schedule a read from the network stack.

	\param terminator
	Provide a pattern to match for the delegate to be called. This can be an
	`NSNumber` object for length or an `NSData` object for bit pattern.

	Accepts an <AFNetworkPacketReading> conforming object too, the timeout and
	context will be set to the given values.
 */
- (void)performRead:(id)terminator withTimeout:(NSTimeInterval)duration context:(void *)context;

 @optional

/*!
	\brief
	Pass a dictionary with the SSL keys specified in CFSocketStream.h

	\details
	Any immediate error is returned by reference, if negotiation fails the error
	will be delivered by delegate callback.
 */
- (BOOL)startTLS:(NSDictionary *)options error:(NSError **)errorRef;

/*!
	\brief
	Determine if SSL/TLS has been started on the connection.
 */
- (BOOL)isSecure;

@end

/*!
	\brief
	This is intentionally empty.
 */
@protocol AFNetworkTransportLayerHostDelegate <NSObject>

@end

/*!
	\brief
	The negative case handling methods are required, otherwise you can assume the connection succeeds.
 */
@protocol AFNetworkTransportLayerControlDelegate <NSObject>

 @optional

- (void)networkLayerDidOpen:(id <AFNetworkTransportLayer>)layer;

- (void)networkLayerDidStartTLS:(id <AFNetworkTransportLayer>)layer;

- (void)networkLayerDidClose:(id <AFNetworkTransportLayer>)layer;

 @required

/*!
	\brief
	This is called for already opened stream errors.
 */
- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didReceiveError:(NSError *)error;

@end

/*!
	\brief
	These methods inform the data delegate of successful reads and writes.
 */
@protocol AFNetworkTransportLayerDataDelegate <NSObject>

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didWrite:(AFNetworkPacket <AFNetworkPacketWriting> *)packet context:(void *)context;

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didRead:(AFNetworkPacket <AFNetworkPacketReading> *)packet context:(void *)context;

@end
