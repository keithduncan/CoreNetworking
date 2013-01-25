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
	An `AFNetworkTransportLayer` object should encapsulate data (as defined in IETF-RFC-1122 <http://tools.ietf.org/html/rfc1122>
	
	\details
	A layer should pass data to it's superclass for further processing, the top-level superclass will pass the data to the lower layer. This creates a two dimensional chain allowing for maximum flexiblity.
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
 
	\details
	This is a good candidate for a block callback argument, allowing for asynchronous -open methods and eliminating the delegate callbacks.
 */
- (void)open;

/*!
	\return
	YES if the layer is currently open.
 */
- (BOOL)isOpen;

/*!
	\details
	A layer may elect to remain open, in which case you will not receive the -networkLayerDidClose: delegate callback until it actually closes.
 */
- (void)close;

/*!
	\brief
	Many layers are linear non-recurrant in nature, like a TCP stream; once closed it cannot be reopened.
 */
- (BOOL)isClosed;

/*!
	\brief
	`buffer` is an `NSData` object to write over the file descriptor
	Accepts an `AFNetworkPacket` subclass too, the tag and timeout of the packet will be set with the values you provide.
 */
- (void)performWrite:(id)buffer withTimeout:(NSTimeInterval)duration context:(void *)context;

/*!
	\param terminator
	Provide a pattern to match for the delegate to be called. This can be an `NSNumber` object for length or an `NSData` object for bit pattern.
	Accepts an `AFNetworkPacket` subclass too, the tag and timeout of the packet will be set with the values you provide.
 */
- (void)performRead:(id)terminator withTimeout:(NSTimeInterval)duration context:(void *)context;

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
