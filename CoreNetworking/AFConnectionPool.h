//
//  ANConnectionPool.h
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AFConnection;

/*!
	@class
	@abstract	This class will take on a more important role later on, I intend for it to become an interface to a thread pool too.
 */
@interface AFConnectionPool : NSObject {
	NSMutableSet *_connections;
}

@property (readonly) NSSet *connections;

- (void)addConnectionsObject:(id)proxy;
- (void)removeConnectionsObject:(id)proxy;

/*!
	@method
 */
- (id)connectionWithValue:(id)value forKey:(NSString *)key;

/*!
	@method
 */
- (void)disconnect;

@end
