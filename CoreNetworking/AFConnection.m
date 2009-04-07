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

@synthesize peerEndpoint=_peerEndpoint;
@synthesize delegate=_delegate;
@synthesize lowerLayer=_lowerLayer;

- (id)initWithLowerLayer:(id <AFNetworkLayer>)lowerLayer delegate:(id <AFConnectionLayerDataDelegate, AFConnectionLayerControlDelegate>)delegate {
	self = [self init];
	
	_delegate = delegate;
	
	_lowerLayer = [lowerLayer retain];
	_lowerLayer.delegate = (id)self;
	
	return self;
}

- (void)dealloc {
	[_peerEndpoint release];
	[_lowerLayer release];
	
	[super dealloc];
}

- (id)forwardingTargetForSelector:(SEL)selector {
	return self.lowerLayer;
}

- (BOOL)respondsToSelector:(SEL)selector {
	return ([super respondsToSelector:selector] || [[self forwardingTargetForSelector:selector] respondsToSelector:selector]);
}

@end
