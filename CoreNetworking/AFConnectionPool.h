//
//  ANConnectionPool.h
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "CoreNetworking/CoreNetworking.h"

@class AFConnection;

@interface AFConnectionPool : NSObject {
	NSMutableSet *connections;
}

@property (readonly, copy) NSSet *connections;

- (void)addConnectionsObject:(id)proxy;
- (void)removeConnectionsObject:(id)proxy;

- (id)connectionWithValue:(id)value forKey:(NSString *)key;

- (void)disconnect;

@end
