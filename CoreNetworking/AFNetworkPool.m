//
//  ANConnectionPool.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008. All rights reserved.
//

#import "AFNetworkPool.h"

@interface AFNetworkPool ()
@property (retain) NSMutableSet *mutableConnections;
@end

@implementation AFNetworkPool

@synthesize mutableConnections=_connections;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_connections = [[NSMutableSet alloc] init];
	
	return self;
}

- (void)dealloc {
	[_connections release];
	
	[super dealloc];
}

- (NSSet *)connections {
	return [[_connections copy] autorelease];
}

- (void)addConnectionsObject:(id <AFNetworkTransportLayer>)connection {
	[self.mutableConnections addObject:connection];
	[connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)removeConnectionsObject:(id <AFNetworkTransportLayer>)connection {
	[connection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[self.mutableConnections removeObject:connection];
}

- (id <AFNetworkTransportLayer>)layerWithValue:(id)value forKey:(NSString *)key {
	id <AFNetworkTransportLayer> connection = nil;
	
	for (id <AFNetworkTransportLayer> currentConnection in self.connections) {
		id connectionValue = [(id)currentConnection valueForKey:key];
		if (![connectionValue isEqual:value]) continue;
		
		connection = currentConnection;
		break;
	}
	
	return connection;
}

- (void)close {
	[self.connections makeObjectsPerformSelector:@selector(close)];
}

@end
