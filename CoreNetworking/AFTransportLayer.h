//
//  AFNetworkLayer.h
//  Bonjour
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFPacket.h"

/*
 *	Network Layers
 *		Transport + Internetwork
 */

@protocol AFNetworkLayerHostDelegate;
@protocol AFNetworkLayerControlDelegate;
@protocol AFNetworkLayerDataDelegate;

#pragma mark -

/*!
    @brief
	An AFTransportLayer object should encapsulate data (as defined in RFC 1122)
 
	@details
	This implementation mandates that a layer pass data to it's superclass for further processing, the top-level superclass will pass the data to the lower layer. This creates a cluster-chain allowing for maximum flexiblity.
*/
@protocol AFTransportLayer <NSObject>

/*!
	@brief
	Currently the control and data delegates share the same property.
 */
@property (assign) id <AFNetworkLayerDataDelegate, AFNetworkLayerControlDelegate> delegate;

/*!
	@brief
	Designated Initialiser.
	
	@details
	For the moment this is designed to be used for an inbound network communication initialisation chain, outbound initialisers have a more specific signatures.
 */
- (id)initWithLowerLayer:(id <AFTransportLayer>)layer;

/*!
	@brief
	This method is useful for accessing lower level properties.
 */
- (id <AFTransportLayer>)lowerLayer;

 @optional

/*!
	@brief
	The delegate callbacks will convey success or failure.
 
	@details
	This is a good candidate for a block callback argument, allowing for asynchronous -open methods and eliminating the delegate callbacks.
 */
- (void)open;

/*!
	@result
	YES if the layer is currently open.
 */
- (BOOL)isOpen;

/*!
	@details
	A layer may elect to remain open, in which case you will not receive the -layerDidClose: delegate callback until it actually closes.
 */
- (void)close;

/*!
	@brief
	Many layers are linear non-recurrant in nature, like a TCP stream; once closed it cannot be reopened.
 */
- (BOOL)isClosed;

/*!
	@brief
	The socket connection must be scheduled in at least one run loop to function.
 */
- (void)scheduleInRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode;

/*!
	@brief
	The socket connection must remain scheduled in at least one run loop to function.
 */
- (void)unscheduleFromRunLoop:(NSRunLoop *)loop forMode:(NSString *)mode;

#if defined(DISPATCH_API_VERSION)

/*!
	@brief
	Creates a dispatch source.
	
	@param queue
	A layer can only be scheduled in a single queue at a time, to unschedule it pass NULL.
 */
- (void)scheduleInQueue:(dispatch_queue_t)queue;

#endif

/*!
	@brief
	|buffer| should be an NSData to write over the file descriptor
	This method should accept a AFPacket subclass, the tag and timeout of the packet will be set with the values you provide.
 */
- (void)performWrite:(id)buffer withTimeout:(NSTimeInterval)duration context:(void *)context;

/*!
	@param
	|terminator| provide a pattern to match for the delegate to be called. This can be an NSNumber for length or an NSData for bit pattern.
	This method should also accept an AFPacket subclass, the tag and timeout of the packet will be set with the values you provide.
 */
- (void)performRead:(id)terminator withTimeout:(NSTimeInterval)duration context:(void *)context;

@end

/*!
	@brief
	This is intentionally empty.
 */
@protocol AFTransportLayerHostDelegate <NSObject>

@end

/*!
	@brief
	The negative case handling methods are required, otherwise you can assume the connection succeeds.
 */
@protocol AFTransportLayerControlDelegate <NSObject>

 @optional

- (void)layerDidOpen:(id <AFTransportLayer>)layer;

- (void)layerDidStartTLS:(id <AFTransportLayer>)layer;

- (void)layerDidClose:(id <AFTransportLayer>)layer;

 @required

/*!
	@brief
	This is called if opening the layer fails asynchronously.
 */
- (void)layer:(id <AFTransportLayer>)layer didNotOpen:(NSError *)error;

/*!
	@brief
	This is called if the TLS fails, the error should be suitable for presenting.
 */
- (void)layer:(id <AFTransportLayer>)layer didNotStartTLS:(NSError *)error;

/*!
	@brief
	This is called for already opened stream errors.
 */
- (void)layer:(id <AFTransportLayer>)layer didReceiveError:(NSError *)error;

@end

/*!
	@brief
	These methods inform the data delegate of successful reads and writes.
 */
@protocol AFTransportLayerDataDelegate <NSObject>

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data context:(void *)context;

- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data context:(void *)context;

@end
