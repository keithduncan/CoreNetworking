//
//  ANConnection.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnection.h"

#import "AmberFoundation/AFPriorityProxy.h"

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
	[_lowerLayer release];
	[_proxy release];
	
	[_peerEndpoint release];
	
	[super dealloc];
}

- (AFPriorityProxy *)delegateProxy:(AFPriorityProxy *)proxy {
	if (proxy == nil) proxy = [[[AFPriorityProxy alloc] init] autorelease];
	
	if ([_delegate respondsToSelector:@selector(delegateProxy:)]) proxy = [(id)_delegate delegateProxy:proxy];
	[proxy insertTarget:_delegate atPriority:0];
	
	return proxy;
}

- (id <AFConnectionLayerControlDelegate, AFConnectionLayerDataDelegate>)delegate {
	return [self delegateProxy:nil];
}

- (id)forwardingTargetForSelector:(SEL)selector {
	return self.lowerLayer;
}

- (BOOL)respondsToSelector:(SEL)selector {
	return ([super respondsToSelector:selector] || [[self forwardingTargetForSelector:selector] respondsToSelector:selector]);
}

@end
