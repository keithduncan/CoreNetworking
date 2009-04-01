//
//  ANConnection.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnection.h"

@implementation AFConnection

@synthesize destinationEndpoint;
@synthesize delegate;
@synthesize lowerLayer;

- (void)dealloc {
	[destinationEndpoint release];
	[lowerLayer release];
	
	[super dealloc];
}

#if 0
- (void)open {
	[self.lowerLayer open];
}

- (BOOL)isOpen {
	return [self.lowerLayer isOpen];
}

- (void)close {
	[self.lowerLayer close];
}

- (BOOL)isClosed {
	return [self.lowerLayer isClosed];
}

- (void)layerDidOpen:(id <AFConnectionLayer>)layer {
	if ([self.delegate respondsToSelector:_cmd]) [self.delegate layerDidOpen:self];
}

- (void)layerDidClose:(id <AFConnectionLayer>)layer; {
	if ([self.delegate respondsToSelector:_cmd]) [self.delegate layerDidClose:self];
}

- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	[self.lowerLayer performWrite:data forTag:tag withTimeout:duration];
}

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	[self.lowerLayer performRead:terminator forTag:tag withTimeout:duration];
}

- (BOOL)startTLS:(NSDictionary *)options {
	return [self.lowerLayer startTLS:options];
}
#else
- (id)forwardingTargetForSelector:(SEL)selector {
	return self.lowerLayer;
}
#endif

@end
