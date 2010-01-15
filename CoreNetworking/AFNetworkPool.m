//
//  ANConnectionPool.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFNetworkPool.h"

#import "AFConnectionLayer.h"

@interface AFNetworkPool ()
@property (retain) NSMutableSet *mutableConnections;
@end

@implementation AFNetworkPool

@synthesize mutableConnections=_connections;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	self.mutableConnections = [NSMutableSet set];
	
	return self;
}

- (void)dealloc {
	self.mutableConnections = nil;
	
	[super dealloc];
}

- (NSSet *)connections {
	return self.mutableConnections;
}

- (void)addConnectionsObject:(id <AFTransportLayer>)connection {
	[self.mutableConnections addObject:connection];
	
	[connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)removeConnectionsObject:(id <AFTransportLayer>)connection {
	[connection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	
	[self.mutableConnections removeObject:connection];
}

- (id <AFTransportLayer>)layerWithValue:(id)value forKey:(NSString *)key {
	id <AFConnectionLayer> connection = nil;
	
	for (id <AFConnectionLayer> currentConnection in self.connections) {
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
