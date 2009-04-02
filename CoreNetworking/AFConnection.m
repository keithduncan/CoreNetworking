//
//  ANConnection.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnection.h"

@interface AFConnection ()
@property (readwrite, retain) id <AFNetworkLayer> lowerLayer;
@end

@implementation AFConnection

@synthesize destinationEndpoint=_destinationEndpoint;
@synthesize delegate=_delegate;
@synthesize lowerLayer=_lowerLayer;

- (id)initWithLowerLayer:(id <AFNetworkLayer>)lowerLayer delegate:(id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate>)delegate {
	self = [self init];
	
	_delegate = delegate;
	_lowerLayer = [lowerLayer retain];
	
	return self;
}

- (void)dealloc {
	[_destinationEndpoint release];
	[_lowerLayer release];
	
	[super dealloc];
}

#if 1

- (id)forwardingTargetForSelector:(SEL)selector {
	return self.lowerLayer;
}

#else

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

- (void)performWrite:(id)data forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	[self.lowerLayer performWrite:data forTag:tag withTimeout:duration];
}

- (void)performRead:(id)terminator forTag:(NSUInteger)tag withTimeout:(NSTimeInterval)duration {
	[self.lowerLayer performRead:terminator forTag:tag withTimeout:duration];
}

- (BOOL)startTLS:(NSDictionary *)options {
	return [self.lowerLayer startTLS:options];
}

- (void)layerDidOpen:(id <AFConnectionLayer>)layer {
	if ([self.delegate respondsToSelector:_cmd]) [self.delegate layerDidOpen:self];
}

- (void)layerDidNotOpen:(id <AFConnectionLayer>)layer {
	if ([self.delegate respondsToSelector:_cmd]) [self.delegate layerDidNotOpen:self];
}

- (void)layerDidClose:(id <AFConnectionLayer>)layer; {
	if ([self.delegate respondsToSelector:_cmd]) [self.delegate layerDidClose:self];
}

#endif

@end
