//
//  AFNetworkConnection.h
//  Amber
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFConnectionLayer.h"

/*!
	@brief	Your subclass should encapsulate Application Layer data (as defined in RFC 1122) and pass it to the superclass for further processing.
*/
@interface AFNetworkConnection : AFNetworkLayer <AFConnectionLayer>

- (AFNetworkLayer <AFConnectionLayer> *)lowerLayer;

@property (assign) id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate> delegate;

/*!
	@brief
	This method returns nil for an inbound connection.
	Otherwise, this method returns the CFHostRef hostname, or the CFNetServiceRef fullname.
 */
- (NSURL *)peer;

@end
