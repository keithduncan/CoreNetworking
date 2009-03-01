//
//  ANConnection.h
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AmberNetworking.h"

/*!
    @class
    @abstract	Should encapsulate Application Layer data, as defined in RFC 1122 and pass it to the |lowerLayer| for further processing
*/

@interface AFConnection : NSObject <AFConnectionLayer, AFConnectionLayerControlDelegate> {	
	NSURL *_destinationEndpoint;
	id <AFNetworkLayer> _lowerLayer;
	
	id <AFConnectionLayerControlDelegate> _delegate;
}

@property (retain) id <AFNetworkLayer, AFConnectionLayer> lowerLayer;

- (id)initWithDestination:(NSURL *)destinationEndpoint;
@property (readonly, copy) NSURL *destinationEndpoint;

@property (assign) id <AFConnectionLayerControlDelegate> delegate;

- (BOOL)startTLS:(NSDictionary *)options;

@end
