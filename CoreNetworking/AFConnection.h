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
    @abstract	Will forward messages to the |lowerLayer|.
	@discussion	Your subclass should encapsulate Application Layer data (as defined in RFC 1122) and pass it to the superclass for further processing.
*/
@interface AFConnection : NSObject <AFConnectionLayer> {
 @private
	id <AFConnectionLayer> _lowerLayer;
	
	id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate> _delegate;
}

/*
 *	Inbound Connections
 */

/*!
	@method
	@abstract	This is used for inbound connections.
	@discussion	This assigns the |lowerLayer| delegate to self.
				The delegate must be provided at this stage because the peer has already connected to us.
 */
- (id)initWithLowerLayer:(id <AFConnectionLayer>)lowerLayer;

/*!
	@property
 */
@property (readonly, retain) id <AFConnectionLayer> lowerLayer;

/*!
	@property
 */
@property (assign) id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate> delegate;

@end
