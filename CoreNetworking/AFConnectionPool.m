//
//  ANConnectionPool.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnectionPool.h"

#import "AFConnectionLayer.h"

@interface AFConnectionPool ()
@property (retain) NSMutableSet *mutableConnections;
@end

@implementation AFConnectionPool

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
	return [[self.mutableConnections copy] autorelease];
}

- (void)addConnectionsObject:(id <AFNetworkLayer>)connection {
	[self.mutableConnections addObject:connection];
	
	[connection scheduleInRunLoop:CFRunLoopGetCurrent() forMode:kCFRunLoopDefaultMode];
}

- (void)removeConnectionsObject:(id <AFNetworkLayer>)connection {
	[connection unscheduleFromRunLoop:CFRunLoopGetCurrent() forMode:kCFRunLoopDefaultMode];
	
	[self.mutableConnections removeObject:connection];
}

- (id <AFNetworkLayer>)connectionWithValue:(id)value forKey:(NSString *)key {
	id <AFConnectionLayer> connection = nil;
	
	for (id <AFConnectionLayer> currentConnection in self.connections) {
		id connectionValue = [(id)currentConnection valueForKey:key];
		if (![connectionValue isEqual:value]) continue;
		
		connection = currentConnection;
		break;
	}
	
	return connection;
}

- (void)disconnect {
	[self.connections makeObjectsPerformSelector:@selector(disconnect)];
}

@end
