//
//  AFNetworkLayer.m
//  Amber
//
//  Created by Keith Duncan on 04/05/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFNetworkLayer.h"

#import <objc/runtime.h>

#import "AmberFoundation/AFPriorityProxy.h"

@interface AFNetworkLayer ()
@property (readwrite, retain) AFNetworkLayer *lowerLayer;
@property (readwrite, retain) NSMutableDictionary *transportInfo;
@end

@implementation AFNetworkLayer

@synthesize lowerLayer = _lowerLayer;
@synthesize delegate=_delegate;
@synthesize transportInfo=_transportInfo;

+ (Class)lowerLayer {
	return Nil;
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_transportInfo = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (id)initWithLowerLayer:(id <AFTransportLayer>)layer {
	self = [self init];
	if (self == nil) return nil;
	
	_lowerLayer = [layer retain];
	_lowerLayer.delegate = (id)self;
	
	return self;
}

- (id <AFTransportLayer>)initWithPeerSignature:(const AFNetworkTransportHostSignature *)signature {	
	id <AFTransportLayer> lowerLayer = [[[(id)[[self class] lowerLayer] alloc] initWithPeerSignature:signature] autorelease];
	return [self initWithLowerLayer:lowerLayer];
}

- (id <AFTransportLayer>)initWithNetService:(id <AFNetServiceCommon>)netService {
	id <AFTransportLayer> lowerLayer = [[[(id)[[self class] lowerLayer] alloc] initWithNetService:netService] autorelease];
	return [self initWithLowerLayer:lowerLayer];
}

- (void)dealloc {
	[_lowerLayer release];
	[_transportInfo release];
	
	[super dealloc];
}

- (id)forwardingTargetForSelector:(SEL)selector {
	return self.lowerLayer;
}

- (BOOL)respondsToSelector:(SEL)selector {
	return ([super respondsToSelector:selector] || [[self forwardingTargetForSelector:selector] respondsToSelector:selector]);
}

- (AFPriorityProxy *)delegateProxy:(AFPriorityProxy *)proxy {	
	if (_delegate == nil) return proxy;
	
	if (proxy == nil) proxy = [[[AFPriorityProxy alloc] init] autorelease];
	
	if ([_delegate respondsToSelector:@selector(delegateProxy:)]) proxy = [(id)_delegate delegateProxy:proxy];
	[proxy insertTarget:_delegate];
	
	return proxy;
}

- (id)delegate {
	return [self delegateProxy:nil];
}

- (void)layerDidOpen:(id)layer {
	if (layer == self.lowerLayer) layer = self;
	[self.delegate layerDidOpen:layer];
}

@end
