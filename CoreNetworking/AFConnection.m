//
//  ANConnection.m
//  Bonjour
//
//  Created by Keith Duncan on 25/12/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "AFConnection.h"

#import <objc/runtime.h>

#import "AmberFoundation/AFPriorityProxy.h"

@interface AFConnection ()
@property (readwrite, retain) id <AFConnectionLayer> lowerLayer;
@end

@implementation AFConnection

@synthesize delegate=_delegate;
@synthesize lowerLayer=_lowerLayer;

- (id)initWithLowerLayer:(id <AFConnectionLayer>)lowerLayer {
	self = [self init];
	if (self == nil) return nil;
	
	self.lowerLayer = lowerLayer;
	self.lowerLayer.delegate = (id)self;
	
	return self;
}

- (void)dealloc {
	self.lowerLayer = nil;
	
	[super dealloc];
}

- (AFPriorityProxy *)delegateProxy:(AFPriorityProxy *)proxy {
	if (proxy == nil) proxy = [[[AFPriorityProxy alloc] init] autorelease];
	
	id delegate = nil;
	object_getInstanceVariable(self, "_delegate", (void **)&delegate);
	
	if ([delegate respondsToSelector:@selector(delegateProxy:)]) proxy = [(id)delegate delegateProxy:proxy];
	[proxy insertTarget:delegate atPriority:0];
	
	return proxy;
}

- (id <AFConnectionLayerControlDelegate, AFConnectionLayerDataDelegate>)delegate {
	return (id <AFConnectionLayerControlDelegate, AFConnectionLayerDataDelegate>)[self delegateProxy:nil];
}

- (id)forwardingTargetForSelector:(SEL)selector {
	return self.lowerLayer;
}

- (BOOL)respondsToSelector:(SEL)selector {
	return ([super respondsToSelector:selector] || [[self forwardingTargetForSelector:selector] respondsToSelector:selector]);
}

@end
