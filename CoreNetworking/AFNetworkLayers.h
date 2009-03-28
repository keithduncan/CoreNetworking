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

@protocol AFNetworkLayerDataDelegate;
@protocol AFNetworkLayerControlDelegate;

/*!
    @protocol
    @abstract	An AFNetworkLayer object should encapsulate data (as defined in RFC 1122)
	@discussion	This implementation mandates that a layer pass data to it's superclass for further processing, the top-level superclass will pass the data to the lower layer. This creates a cluster-chain allowing for maximum flexiblity.
*/
@protocol AFNetworkLayer <NSObject>

@property (assign) id <AFNetworkLayerDataDelegate, AFNetworkLayerControlDelegate> delegate;

- (void)open;
- (BOOL)isOpen;

- (void)close;
- (BOOL)isClosed;

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;
- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

 @optional

// Pass a dictionary with the keys in CFSocketStreams
- (BOOL)startTLS:(NSDictionary *)options;

@end

@protocol AFNetworkLayerControlDelegate <NSObject>
- (void)layerDidOpen:(id <AFNetworkLayer>)layer;
- (void)layerDidNotOpen:(id <AFNetworkLayer>)layer;
- (void)layerDidClose:(id <AFNetworkLayer>)layer;
@end

@protocol AFNetworkLayerDataDelegate <NSObject>
@property (readonly, retain) id <AFNetworkLayer> lowerLayer;
- (void)layer:(id <AFNetworkLayer>)layer didRead:(id)data forTag:(NSUInteger)tag;
- (void)layer:(id <AFNetworkLayer>)layer didWrite:(id)data forTag:(NSUInteger)tag;
 @optional
- (void)layerDidStartTLS:(id <AFNetworkLayer>)layer;
@end

@protocol AFNetworkLayerHostDelegate
- (void)layer:(id <AFNetworkLayer>)layer didAcceptConnection:(id <AFNetworkLayer>)newLayer;
@end

/*
 *	Connection Layers
 */

@protocol AFConnectionLayerControlDelegate;

/*!
	@protocol
	@abstract    An AFConnectionLayer should maintain a stateful connection between endpoints
 */
@protocol AFConnectionLayer <AFNetworkLayer>
@property (assign) id <AFConnectionLayerControlDelegate> delegate;
@end

@protocol AFConnectionLayerControlDelegate <AFNetworkLayerControlDelegate>
 @optional
- (void)layerDidConnect:(id <AFConnectionLayer>)layer toPeer:(CFHostRef)peer;
- (void)layerWillDisconnect:(id <AFConnectionLayer>)layer withError:(NSError *)error;
@end

/*
 *	Connectionless Layers
 */

// Note: I need to use UDP first, then figure out what the API should be
