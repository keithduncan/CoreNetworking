//
//  ANConnectionPool.h
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFTransportLayer.h"

@class AFNetworkConnection;

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
- (void)addConnectionsObject:(id <AFTransportLayer>)proxy;

/*!
	@method
 */
- (void)removeConnectionsObject:(id <AFTransportLayer>)proxy;

/*!
	@method
 */
- (id <AFTransportLayer>)connectionWithValue:(id)value forKey:(NSString *)key;

/*!
	@method
 */
- (void)disconnect;

@end
