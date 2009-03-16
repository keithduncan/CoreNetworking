//
//  ANConnectionPool.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnectionPool.h"

@implementation AFConnectionPool

@synthesize connections;

- (id)init {
	[super init];
	
	connections = [[NSMutableSet alloc] init];
	
	return self;
}

- (void)dealloc {
	[connections release];
	
	[super dealloc];
}

- (NSSet *)connections {
	return [[connections copy] autorelease];
}

- (void)addConnectionsObject:(id)connection {
	[connections addObject:connection];
}

- (void)removeConnectionsObject:(id)connection {
	[connections removeObject:connection];
}

- (id)connectionWithValue:(id)value forKey:(NSString *)key {
	id <AFConnectionLayer> connection = nil;
	
	for (id <AFConnectionLayer> currentConnection in self.connections) {
		id connectionValue = [currentConnection valueForKey:key];
		if (![connectionValue isEqual:value]) continue;
		
		connection = currentConnection;
		break;
	}
	
	return connection;
}

- (void)disconnect; {
	[self.connections makeObjectsPerformSelector:@selector(disconnect)];
}

@end
