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

- (void)addConnectionsObject:(AFConnection *)connection {
	[connections addObject:connection];
}

- (void)removeConnectionsObject:(AFConnection *)connection {
	[connections removeObject:connection];
}

- (id)connectionWithValue:(id)value forKey:(NSString *)key {
	AFConnection *connection = nil;
	
	for (AFConnection *currentConnection in self.connections) {
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
