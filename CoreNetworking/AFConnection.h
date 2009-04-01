//
//  ANConnection.h
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFConnectionLayer.h"

/*!
    @class
    @abstract	Will pass data to the |lowerLayer| for further processing
	@discussion	Your subclass should encapsulate Application Layer data (as defined in RFC 1122) and pass it to the super class for further processing
*/

@interface AFConnection : NSObject <AFConnectionLayer, AFConnectionLayerControlDelegate> {
 @private
	NSURL *destinationEndpoint;
	id <AFConnectionLayerControlDelegate> delegate;
	
	id <AFNetworkLayer> lowerLayer;
}

/*!
	@property
 */
@property (copy) NSURL *destinationEndpoint;

/*!
	@property
 */
@property (assign) id <AFConnectionLayerControlDelegate> delegate;

@end
