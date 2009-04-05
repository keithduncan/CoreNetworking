//
//  AFConnectionLayer.h
//  Amber
//
//  Created by Keith Duncan on 31/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

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
@property (assign) id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate> delegate;
@end

@protocol AFConnectionLayerHostDelegate <AFNetworkLayerHostDelegate>
/*!
	@method
	@abstract	|layer| could be the host that spawned it or an intermediate object
 */
- (void)layer:(id)layer didAcceptConnection:(id <AFNetworkLayer>)layer;
@end

@protocol AFConnectionLayerControlDelegate <AFNetworkLayerControlDelegate>

 @optional
/*!
	@method
	@abstract	This method is paired with <tt>-layerDidOpen:</tt> and MUST be sent after it.
 */
- (void)layer:(id <AFConnectionLayer>)layer didConnectToPeer:(id)peer;

/*!
	@method
	@abstract	This method is paired with <tt>-layerDidClose:</tt> and MUST be sent after it.
	@discussion	This method signals disconnection in both clean and dirty conditions, the |error| argument may be nil.
 */
- (void)layer:(id <AFConnectionLayer>)layer didDisconnectWithError:(NSError *)error;

@end

@protocol AFConnectionLayerDataDelegate <AFNetworkLayerDataDelegate>

@end
