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
- (void)layer:(id <AFConnectionLayer>)layer didAcceptConnection:(id <AFNetworkLayer>)layer;
@end

@protocol AFConnectionLayerControlDelegate <AFNetworkLayerControlDelegate>
 @optional
- (void)layer:(id <AFConnectionLayer>)layer didConnectToPeer:(CFHostRef)peer;
- (void)layer:(id <AFConnectionLayer>)layer didDisconnectWithError:(NSError *)error;
@end

@protocol AFConnectionLayerDataDelegate <AFNetworkLayerDataDelegate>

@end
