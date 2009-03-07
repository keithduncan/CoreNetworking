//
//  ANConnection.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnection.h"

@interface AFConnection ()
@property (readwrite, copy) NSURL *destinationEndpoint;
@end

@implementation AFConnection

@synthesize destinationEndpoint=_destinationEndpoint;
@synthesize lowerLayer=_lowerLayer;

@synthesize delegate=_delegate;

- (id)initWithDestination:(NSURL *)destinationEndpoint {
	[self init];
	
	self.destinationEndpoint = destinationEndpoint;
	
	return self;
}

- (void)dealloc {
	[_destinationEndpoint release];
	[_lowerLayer release];
	
	[super dealloc];
}

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

@end
