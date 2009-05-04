//
//  AFConnectionLayer.h
//  Amber
//
//  Created by Keith Duncan on 31/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

/*
 *	Connection Layers
 */

@protocol AFConnectionLayerHostDelegate;
@protocol AFConnectionLayerControlDelegate;
@protocol AFConnectionLayerDataDelegate;

#pragma mark -

/*!
	@protocol
	@abstract    An AFConnectionLayer should maintain a stateful connection between endpoints
 */
@protocol AFConnectionLayer <AFNetworkLayer>

/*!
	@property
 */
@property (assign) id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate> delegate;

@end

/*!
	@protocol
 */
@protocol AFConnectionLayerHostDelegate <AFNetworkLayerHostDelegate>
/*!
	@method
	@abstract	|layer| could be the host that spawned it or an intermediate object
 */
- (void)layer:(id)layer didAcceptConnection:(id <AFNetworkLayer>)layer;
@end

/*!
	@protocol
 */
@protocol AFConnectionLayerControlDelegate <AFNetworkLayerControlDelegate>

 @optional

/*!
	@method
	@abstract	This method is paired with <tt>-layerDidOpen:</tt> and MUST be sent AFTER it.
	@param		|peer| might be a (CFHostRef) or (CFNetServiceRef) depending on what the connection layer was instantiated with. Use CFGetTypeID() to determine which you've been passed.
 */
- (void)layer:(id <AFConnectionLayer>)layer didConnectToPeer:(id)peer;

/*!
	@method
	@abstract	This method is paired with <tt>-layerDidClose:</tt> and MUST be sent BEFORE it.
	@discussion	This method signals disconnection in both clean and dirty conditions, the |error| argument will be nil to signify a clean disconnection.
				If calling this method on the delegate where the |error| parameter is non-nil, you MUST first call <tt>-layer:didReceiveError:</tt>.
 */
- (void)layer:(id <AFConnectionLayer>)layer didDisconnectWithError:(NSError *)error;

@end

/*!
	@protocol
 */
@protocol AFConnectionLayerDataDelegate <AFNetworkLayerDataDelegate>

@end
