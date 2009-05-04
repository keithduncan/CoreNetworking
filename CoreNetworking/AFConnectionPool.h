//
//  ANConnectionPool.h
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkLayer.h"

@class AFConnection;

/*!
	@class
	@abstract	The pool will automatically schedule added connections.
 */
@interface AFConnectionPool : NSObject {
	NSMutableSet *_connections;
}

/*!
	@property
 */
@property (readonly) NSSet *connections;

/*!
	@method
 */
- (void)addConnectionsObject:(id <AFNetworkLayer>)proxy;

/*!
	@method
 */
- (void)removeConnectionsObject:(id <AFNetworkLayer>)proxy;

/*!
	@method
 */
- (id <AFNetworkLayer>)connectionWithValue:(id)value forKey:(NSString *)key;

/*!
	@method
 */
- (void)disconnect;

@end
