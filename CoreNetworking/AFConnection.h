//
//  ANConnection.h
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/AFNetworkLayer.h"

#import "CoreNetworking/AFConnectionLayer.h"

/*!
    @class
    @abstract	Will forward messages to the |lowerLayer|.
	@discussion	Your subclass should encapsulate Application Layer data (as defined in RFC 1122) and pass it to the superclass for further processing.
*/
@interface AFConnection : AFNetworkLayer <AFConnectionLayer>

/*!
	@property
 */
@property (readonly, retain) id <AFConnectionLayer> lowerLayer;

/*!
	@property
 */
@property (assign) id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate> delegate;

@end
