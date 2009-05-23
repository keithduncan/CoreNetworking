//
//  AFConnectionLayer.h
//  Amber
//
//  Created by Keith Duncan on 31/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFTransportLayer.h"

/*!
 *	Connection Layers
 */

@protocol AFConnectionLayerHostDelegate;
@protocol AFConnectionLayerControlDelegate;
@protocol AFConnectionLayerDataDelegate;

#pragma mark -

/*!
	@brief
	An AFConnectionLayer should maintain a stateful connection between endpoints.
 */
@protocol AFConnectionLayer <AFTransportLayer>

@property (assign) id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate> delegate;

 @optional

/*!
	@brief
	Pass a dictionary with the SSL keys specified in CFSocketStream.h
 */
- (void)startTLS:(NSDictionary *)options;

/*!
	@brief
	This method can be used to determine if SSL/TLS has been started on the connection.
 */
- (BOOL)isSecure;

@end


@protocol AFConnectionLayerHostDelegate <AFTransportLayerHostDelegate>

/*!
	@param
	|layer| could be the host that spawned it or an intermediate object.
 */
- (void)layer:(id)layer didAcceptConnection:(id <AFTransportLayer>)layer;
@end


@protocol AFConnectionLayerControlDelegate <AFTransportLayerControlDelegate>

 @optional

/*!
	@brief
	This method is paired with <tt>-layerDidOpen:</tt> and MUST be sent AFTER it.
 
	@param
	|peer| might be a (CFHostRef) or (CFNetServiceRef) depending on what the connection layer was instantiated with. Use CFGetTypeID() to determine which you've been passed.
 */
- (void)layer:(id <AFConnectionLayer>)layer didConnectToPeer:(id)peer;

/*!
	@brief
	This method is paired with <tt>-layerDidClose:</tt> and MUST be sent BEFORE it.
 
	@detail
	This method signals disconnection in both clean and dirty conditions, the |error| argument will be nil to signify a clean disconnection.
	If calling this method on the delegate where the |error| parameter is non-nil, you MUST first call <tt>-layer:didReceiveError:</tt>.
 */
- (void)layer:(id <AFConnectionLayer>)layer didDisconnectWithError:(NSError *)error;

@end


@protocol AFConnectionLayerDataDelegate <AFNetworkLayerDataDelegate>

@end
