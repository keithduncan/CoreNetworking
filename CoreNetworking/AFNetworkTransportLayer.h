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
 *		Transport + Internetwork
 */

@protocol AFNetworkTransportLayerHostDelegate;
@protocol AFNetworkTransportLayerControlDelegate;
@protocol AFNetworkTransportLayerDataDelegate;

#pragma mark -

/*!
	\brief
	An AFNetworkTransportLayer object should encapsulate data (as defined in IETF-RFC-1122 <http://tools.ietf.org/html/rfc1122>
 
	\details
	This implementation mandates that a layer pass data to it's superclass for further processing, the top-level superclass will pass the data to the lower layer. This creates a cluster-chain allowing for maximum flexiblity.
*/
@protocol AFNetworkTransportLayer <NSObject>

/*!
	\brief
	Currently the control and data delegates share the same property.
 */
@property (assign) id <AFNetworkTransportLayerControlDelegate, AFNetworkTransportLayerDataDelegate> delegate;

/*!
	\brief
	Designated Initialiser.
	
	\details
	For the moment this is designed to be used for an inbound network communication initialisation chain, outbound initialisers have a more specific signatures.
 */
- (id)initWithLowerLayer:(id <AFNetworkTransportLayer>)layer;

/*!
	\brief
	This method is useful for accessing lower level properties.
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
	The socket connection must be scheduled in at least one run loop to function.
 */
- (void)scheduleInRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode;

/*!
	\brief
	The socket connection must remain scheduled in at least one run loop to function.
 */
- (void)unscheduleFromRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode;

#if defined(DISPATCH_API_VERSION)

/*!
	\brief
	Creates a dispatch source internally.
	
	\param queue
	A layer can only be scheduled in a single queue at a time, to unschedule it pass NULL.
 */
- (void)scheduleInQueue:(dispatch_queue_t)queue;

#endif

/*!
	\brief
	|buffer| should be an NSData to write over the file descriptor
	This method should accept a AFPacket subclass, the tag and timeout of the packet will be set with the values you provide.
 */
- (void)performWrite:(id)buffer withTimeout:(NSTimeInterval)duration context:(void *)context;

/*!
	\param terminator
	Provide a pattern to match for the delegate to be called. This can be an NSNumber for length or an NSData for bit pattern.
	This method should also accept an AFPacket subclass, the tag and timeout of the packet will be set with the values you provide.
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

- (void)networkLayerDidClose:(id <AFNetworkTransportLayer>)layer;

 @required

/*!
	\brief
	This is called for already opened stream errors.
 */
- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didReceiveError:(NSError *)error;

 @optional

/*!
	\brief
	Called if TLS setup succeeded.
 */
- (void)networkLayerDidStartTLS:(id <AFNetworkTransportLayer>)layer;

/*!
	\brief
	Called if the TLS fails, will call the generic error handler instead if unimplemented.
 */
- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didNotStartTLS:(NSError *)error;

@end

/*!
	\brief
	These methods inform the data delegate of successful reads and writes.
 */
@protocol AFNetworkTransportLayerDataDelegate <NSObject>

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didWrite:(id)data context:(void *)context;

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didRead:(id)data context:(void *)context;

@end
