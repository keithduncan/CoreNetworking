//
//  ANConnectionPool.h
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AFConnection;

@interface AFConnectionPool : NSObject {
	NSMutableSet *connections;
}

@property (readonly) NSSet *connections;

- (void)addConnectionsObject:(AFConnection *)proxy;
- (void)removeConnectionsObject:(AFConnection *)proxy;

- (id)connectionWithValue:(id)value forKey:(NSString *)key;

- (void)disconnect;

@end
