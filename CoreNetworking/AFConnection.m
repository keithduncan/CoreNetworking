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

- (void)connect {
	
}

- (BOOL)isConnected {
	return [self.lowerLayer isConnected];
}

- (void)disconnect {
	[self.lowerLayer disconnectAfterWriting];
}

- (BOOL)isDisconnected {
	return [self.lowerLayer isDisconnected];
}

- (void)layerDidConnect:(id <AFConnectionLayer>)layer {
	if ([self.delegate respondsToSelector:_cmd]) [self.delegate layerDidConnect:layer];
}

- (void)layerDidDisconnect:(id <AFConnectionLayer>)layer; {
	if ([self.delegate respondsToSelector:_cmd]) [self.delegate layerDidDisconnect:self];
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
