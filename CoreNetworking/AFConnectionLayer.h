//
//  AFConnectionLayer.h
//  Amber
//
//  Created by Keith Duncan on 31/03/2009.
//  Copyright 2009. All rights reserved.
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
	
	@detail
	Any immediate error is returned by reference, if negotiation fails the error will be delivered by 
 */
- (BOOL)startTLS:(NSDictionary *)options error:(NSError **)errorRef;

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

@end

@protocol AFConnectionLayerDataDelegate <AFNetworkLayerDataDelegate>

@end
