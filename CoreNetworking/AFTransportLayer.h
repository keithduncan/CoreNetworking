//
//  AFNetworkLayer.h
//  Bonjour
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
 *	Network Layers
 *		Transport + Internetwork
 */

@protocol AFNetworkLayerHostDelegate;
@protocol AFNetworkLayerControlDelegate;
@protocol AFNetworkLayerDataDelegate;

#pragma mark -

/*!
    @brief	An AFNetworkLayer object should encapsulate data (as defined in RFC 1122)
	@detail	This implementation mandates that a layer pass data to it's superclass for further processing, the top-level superclass will pass the data to the lower layer. This creates a cluster-chain allowing for maximum flexiblity.
*/
@protocol AFTransportLayer <NSObject>

@property (assign) id <AFNetworkLayerDataDelegate, AFNetworkLayerControlDelegate> delegate;

/*!
	@brief
	Designated Initialiser.
	
	@detail
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
 
	@detail
	This is a good candidate for a block callback argument, allowing for asynchronous -open methods and eliminating the delegate callbacks.
 */
- (void)open;

/*!
	@result
	YES if the layer is currently open.
 */
- (BOOL)isOpen;

/*!
	@detail
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
	Pass a dictionary with the SSL keys specified in CFSocketStream.h
 */
- (void)startTLS:(NSDictionary *)options;

/*!
	@brief
	The socket connection must be scheduled in at least one run loop to function.
 */
- (void)scheduleInRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode;

/*!
	@brief
	The socket connection must remain scheduled in at least one run loop to function.
 */
- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode;

/*!
	@param
	|terminator| provide a pattern to match for the delegate to be called. This can be an NSNumber for length, an NSData for bit pattern, or an AFPacketRead subclass for custom behaviour.
 */
- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

/*!
 
 */
- (void)performWrite:(id)dataBuffer forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

@end


@protocol AFTransportLayerHostDelegate <NSObject>

@end


@protocol AFTransportLayerControlDelegate <NSObject>


- (void)layerDidOpen:(id <AFTransportLayer>)layer;

- (void)layer:(id <AFTransportLayer>)layer didNotOpen:(NSError *)error;

/*!
	@brief	This is called for connected-stream errors only.
 */
- (void)layer:(id <AFTransportLayer>)layer didReceiveError:(NSError *)error;

- (void)layerDidClose:(id <AFTransportLayer>)layer;

 @optional

- (void)layerDidStartTLS:(id <AFTransportLayer>)layer;

- (void)layer:(id <AFTransportLayer>)layer didNotStartTLS:(NSError *)error;

@end


@protocol AFTransportLayerDataDelegate <NSObject>

- (void)layer:(id <AFTransportLayer>)layer didRead:(id)data forTag:(NSUInteger)tag;

- (void)layer:(id <AFTransportLayer>)layer didWrite:(id)data forTag:(NSUInteger)tag;

@end
