//
//  AFNetworkLayer.h
//  Bonjour
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 *	Network Layers
 *		Transport + Internetwork
 */

@protocol AFNetworkLayerHostDelegate;
@protocol AFNetworkLayerControlDelegate;
@protocol AFNetworkLayerDataDelegate;

#pragma mark -

/*!
    @protocol
    @abstract	An AFNetworkLayer object should encapsulate data (as defined in RFC 1122)
	@discussion	This implementation mandates that a layer pass data to it's superclass for further processing, the top-level superclass will pass the data to the lower layer. This creates a cluster-chain allowing for maximum flexiblity.
*/
@protocol AFNetworkLayer <NSObject>

/*!
	@property
 */
@property (assign) id <AFNetworkLayerDataDelegate, AFNetworkLayerControlDelegate> delegate;

/*!
	@method
	@abstract	Designated Initialiser, with encapsulation in mind
	@discussion	For the moment this is designed to be used for an inbound network communication initialisation chain, outbound communication will probably have a more specific initialiser
 */
- (id)initWithLowerLayer:(id <AFNetworkLayer>)layer;

/*!
	@property
 */
@property (readonly, retain) id <AFNetworkLayer> lowerLayer;

 @optional

/*!
	@method
	@abstract	The delegate callbacks convey success/failure.
	@discussion	This is a good candidate for a block callback argument, allowing for asynchronous -open methods and eliminating the delegate callbacks.
 */
- (void)open;

/*!
	@method
	@result		YES if the layer is currently open.
 */
- (BOOL)isOpen;

/*!
	@method
	@discussion	A layer may elect to remain open, in which case you will not receive the -layerDidClose: delegate callback until it actually closes.
 */
- (void)close;

/*!
	@method
	@abstract	Many layers are linear non-recurrant in nature, like a TCP stream; once closed it cannot be reopened.
 */
- (BOOL)isClosed;

/*!
	@method
	@abstract	Pass a dictionary with the SSL keys specified in CFSocketStream.h
 */
- (void)startTLS:(NSDictionary *)options;

/*!
 @method
 @abstract	The socket connection must be scheduled in at least one run loop to function.
 */
- (void)scheduleInRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode;

/*!
	@method
	@abstract	The socket connection must remain scheduled in at least one run loop to function.
 */
- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode;

/*!
	@method
	@param		|terminator| provide a pattern to match for the delegate to be called. This can be an NSNumber for length, an NSData for bit pattern, or an AFPacketRead subclass for custom behaviour.
 */
- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

/*!
	@method
 */
- (void)performWrite:(id)dataBuffer forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

@end

/*!
	@protocol
 */
@protocol AFNetworkLayerHostDelegate <NSObject>

@end

/*!
	@protocol
 */
@protocol AFNetworkLayerControlDelegate <NSObject>

/*!
	@method
 */
- (void)layerDidOpen:(id <AFNetworkLayer>)layer;

/*!
	@method
 */
- (void)layer:(id <AFNetworkLayer>)layer didNotOpen:(NSError *)error;

/*!
	@method
 */
- (void)layerDidStartTLS:(id <AFNetworkLayer>)layer;

/*!
	@method
 */
- (void)layer:(id <AFNetworkLayer>)layer didNotStartTLS:(NSError *)error;

/*!
	@method
	@abstract	This is to be called for connected-stream errors only.
 */
- (void)layer:(id <AFNetworkLayer>)layer didReceiveError:(NSError *)error;

/*!
	@method
 */
- (void)layerDidClose:(id <AFNetworkLayer>)layer;

@end

/*!
	@protocol
 */
@protocol AFNetworkLayerDataDelegate <NSObject>

/*!
	@property
 */
@property (readonly, retain) id <AFNetworkLayer> lowerLayer;

/*!
	@method
 */
- (void)layer:(id <AFNetworkLayer>)layer didRead:(id)data forTag:(NSUInteger)tag;

/*!
	@method
 */
- (void)layer:(id <AFNetworkLayer>)layer didWrite:(id)data forTag:(NSUInteger)tag;

@end
