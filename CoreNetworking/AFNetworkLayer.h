//
//  ANStackProtocols.h
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
@property (readonly, retain) id <AFNetworkLayer> lowerLayer;

/*!
	@property
 */
@property (assign) id <AFNetworkLayerDataDelegate, AFNetworkLayerControlDelegate> delegate;

/*!
	@method
	@abstract	Designated Initialiser, with encapsulation in mind
	@discussion	For the moment this is designed to be used for an inbound network communication initialisation chain, outbound communication will probably have a more specific initialiser
 */
- (id)initWithLowerLayer:(id <AFNetworkLayer>)layer delegate:(id <AFNetworkLayerDataDelegate, AFNetworkLayerControlDelegate>)delegate;

/*!
	@method
	@abstract	the delegate callbacks convey success/failure
	@discussion	good candidate for a block callback argument, allowing for asynchronous -open methods and eliminating the delegate callbacks
 */
- (void)open;

/*!
	@method
	@abstract	returns YES if the layer is currently open
 */
- (BOOL)isOpen;

/*!
	@method
	@discussion	a layer may elect to remain open, in which case you will not receive the -layerDidClose: delegate callback until it actually closes
 */
- (void)close;

/*!
	@method
	@abstract	many layers are linear non-recurrant in nature, like a stream; once closed it may not be openable
 */
- (BOOL)isClosed;

 @optional

/*!
	@method
	@abstract	the socket connection must be scheduled in at least one run loop to function
 */
- (void)scheduleInRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode;

/*!
	@method
	@abstract	the socket connection must be scheduled in at least one run loop to function
 */
- (void)unscheduleFromRunLoop:(CFRunLoopRef)loop forMode:(CFStringRef)mode;

/*!
	@method
 */
- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

/*!
	@method
 */
- (void)performWrite:(id)dataBuffer forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

/*!
	@method
	@abstract	Pass a dictionary with the keys in CFSocketStreams
 */
- (BOOL)startTLS:(NSDictionary *)options;

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
- (void)layerDidOpen:(id <AFNetworkLayer>)layer;
- (void)layerDidNotOpen:(id <AFNetworkLayer>)layer;
- (void)layerDidClose:(id <AFNetworkLayer>)layer;
@end

/*!
	@protocol
 */
@protocol AFNetworkLayerDataDelegate <NSObject>
@property (readonly, retain) id <AFNetworkLayer> lowerLayer;
- (void)layer:(id <AFNetworkLayer>)layer didRead:(id)data forTag:(NSUInteger)tag;
- (void)layer:(id <AFNetworkLayer>)layer didWrite:(id)data forTag:(NSUInteger)tag;
 @optional
- (void)layerDidStartTLS:(id <AFNetworkLayer>)layer;
@end
