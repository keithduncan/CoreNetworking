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
@interface AFConnection : NSObject {
 @private
	id <AFNetworkLayer> _lowerLayer;
	id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate> _delegate;
	
	NSURL *_destinationEndpoint;
}

/*!
	@method
	@abstract	This assigns the |lowerLayer| delegate to self
 */
- (id)initWithLowerLayer:(id <AFNetworkLayer>)lowerLayer delegate:(id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate>)delegate;

/*!
	@property
 */
@property (copy) NSURL *destinationEndpoint;

/*!
	@property
 */
@property (assign) id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate> delegate;

/*!
	@method
	@abstract	This is forwarded onto the |lowerLayer| it is simply here to enforce good method funneling
 */
- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

/*!
	@method
	@abstract	This is forwarded onto the |lowerLayer| it is simply here to enforce good method funneling
 */
- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration;

@end
