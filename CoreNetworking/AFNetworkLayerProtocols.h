//
//  ANStackProtocols.h
//  Bonjour
//
//  Created by Keith Duncan on 26/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AFNetworkLayerDataDelegate;

/*!
    @protocol
    @abstract    An AFNetworkLayer object should encapsulate data in the Transport and Internet layers, as defined in RFC 1122
*/

@protocol AFNetworkLayer <NSObject>
 @required

@property (assign) id <AFNetworkLayerDataDelegate> delegate;
- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;
- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

 @optional

// Pass a dictionary with the keys in CFSocketStreams
- (BOOL)startTLS:(NSDictionary *)options;

@end

@protocol AFNetworkLayerDataDelegate <NSObject> // It is assumed that each application layer will provide its own application specific means of writing data to the lower levels
@property (retain) id <AFNetworkLayer> lowerLayer; // Note: whilst the object passed into the stack MUST implement -setLowerLayer: and retain this, should -setLowerLayer: be called on the proxy it WILL NOT be forwarded and WILL throw an exception
- (void)layer:(id <AFNetworkLayer>)object didRead:(id)data forTag:(NSUInteger)tag;
- (void)layer:(id <AFNetworkLayer>)object didWrite:(id)data forTag:(NSUInteger)tag;
@end


@protocol AFConnectionLayerHostDelegate;
@protocol AFConnectionLayerControlDelegate;

/*!
	@protocol
	@abstract    An AFConnectionLayer should maintain a stateful connection between endpoints, it can be applied to either AFNetworkLayer or AFConnection
 */

@protocol AFConnectionLayer <AFNetworkLayer> // Note: TCP => connection, UDP => connectionless, if an Application Layer implements this protocol, so should it's Network Layer
// Note: these MUST share the same storage, a connection layer cannot have both a host and control delegate
@property (assign) id <AFConnectionLayerHostDelegate> hostDelegate;
@property (assign) id <AFConnectionLayerControlDelegate> controlDelegate;

- (void)connect;
- (BOOL)isConnected;

- (void)disconnect;
- (BOOL)isDisconnected;
@end

@protocol AFConnectionLayerHostDelegate <NSObject>
- (void)layer:(id <AFNetworkLayer, AFConnectionLayer>)object didAcceptConnection:(id <AFNetworkLayer, AFConnectionLayer>)layer;
- (void)layer:(id <AFNetworkLayer>)object didConnectToHost:(const struct sockaddr *)host;
@end

@protocol AFConnectionLayerControlDelegate <NSObject>
- (void)layerDidConnect:(id <AFConnectionLayer>)layer;
- (void)layerDidDisconnect:(id <AFConnectionLayer>)layer;
@end

/*!
	@protocol
	@abstract    An AFConnectionlessLayer should not maintain a stateful connection between endpoints, it can be applied to either AFNetworkLayer or AFConnection
	@discussion  There are no control callbacks because there is no handshaking/negotiation
 */

@protocol AFConnectionlessLayer <AFNetworkLayer> // Note: TCP => connection, UDP => connectionless, if an Application Layer implements this protocol, so should it's Network Layer
- (void)prepare;
- (BOOL)isPrepared;

- (void)shutdown;
- (BOOL)isShutdown;
@end
