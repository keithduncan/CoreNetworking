//
//  ANConnection.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFNetworkConnection.h"

@implementation AFNetworkConnection

@dynamic delegate;

- (AFNetworkLayer <AFConnectionLayer> *)lowerLayer {
	return [super lowerLayer];
}

- (NSURL *)peer {
	CFTypeRef peer = [(id)super peer];
	
	if (CFGetTypeID(peer) == CFHostGetTypeID()) {
		NSArray *hostnames = (NSArray *)CFHostGetNames((CFHostRef)peer, NULL);
		NSParameterAssert([hostnames count] == 1);
		
		return [NSURL URLWithString:[hostnames objectAtIndex:0]];
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"%s, cannot determine the peer name.", __PRETTY_FUNCTION__, nil];
	return nil;
}

@end
