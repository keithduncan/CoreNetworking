//
//  ANStackProtocols.h
//  Bonjour
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/CoreNetworking.h"

@protocol AFNetworkLayerDataDelegate;
@protocol AFNetworkLayerControlDelegate;

/*!
    @protocol
    @abstract	An AFNetworkLayer object should encapsulate data (as defined in RFC 1122)
	@discussion	This implementation mandates that a layer pass data to it's superclass for further processing, the top-level superclass will pass the data to the lower layer. This creates a cluster-chain allowing for maximum flexiblity.
*/

@protocol AFNetworkLayer <NSObject>

@property (assign) id <AFNetworkLayerDataDelegate> delegate;
- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;
- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

- (void)open:(NSError **)errorRef;
- (BOOL)isOpen;

- (void)close;
- (BOOL)isClosed;

 @optional

// Pass a dictionary with the keys in CFSocketStreams
- (BOOL)startTLS:(NSDictionary *)options;

@end

@protocol AFNetworkLayerDataDelegate <NSObject> // It is assumed that each application layer will provide its own application specific means of writing data to the lower levels
@property (retain) id <AFNetworkLayer> lowerLayer; // Note: whilst the object passed into the stack MUST implement -setLowerLayer: and retain this, should -setLowerLayer: be called on the proxy it WILL NOT be forwarded and WILL throw an exception
- (void)layer:(id <AFNetworkLayer>)object didRead:(id)data forTag:(NSUInteger)tag;
- (void)layer:(id <AFNetworkLayer>)object didWrite:(id)data forTag:(NSUInteger)tag;
@end

@protocol AFNetworkLayerControlDelegate <NSObject>
- (void)layerDidOpen:(id <AFConnectionLayer>)layer;
- (void)layerDidClose:(id <AFConnectionLayer>)layer;
@end


@protocol AFConnectionLayerHostDelegate;

/*!
	@protocol
	@abstract    An AFConnectionLayer should maintain a stateful connection between endpoints
 */

@protocol AFConnectionLayer <AFNetworkLayer> // Note: TCP => connection, UDP => connectionless, if an Application Layer implements this protocol, so should it's Network Layer
@property (assign) id <AFConnectionLayerHostDelegate> hostDelegate;
@end

/*!
	@protocol
	@abstract	
 */

@protocol AFConnectionLayerHostDelegate <NSObject>
- (void)layer:(id <AFConnectionLayer>)object didAcceptConnection:(id <AFConnectionLayer>)layer;
- (void)layer:(id <AFConnectionLayer>)object didConnectToHost:(CFHostRef)host;
@end
