//
//  AFNetworkObject.m
//  Amber
//
//  Created by Keith Duncan on 04/05/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFNetworkLayer.h"

#import <objc/runtime.h>

#import "AmberFoundation/AFPriorityProxy.h"

@interface AFNetworkLayer ()
- (void)setLowerLayer:(AFNetworkLayer *)layer;
@property (readwrite, retain) NSMutableDictionary *transportInfo;
@end

@implementation AFNetworkLayer

@synthesize delegate=_delegate;
@synthesize transportInfo=_transportInfo;

+ (const AFNetworkTransportSignature *)transportSignatureForScheme:(NSString *)scheme {
	[NSException raise:NSInvalidArgumentException format:@"%s, cannot provide an AFNetworkTransportSignature for scheme (%@)", __PRETTY_FUNCTION__, scheme, nil];
	return NULL;
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	self.transportInfo = [NSMutableDictionary dictionary];
	
	return self;
}

- (id)initWithLowerLayer:(id <AFTransportLayer>)layer {
	self = [self init];
	if (self == nil) return nil;
	
	self.lowerLayer = layer;
	self.lowerLayer.delegate = (id)self;
	
	return self;
}

- (id <AFTransportLayer>)initWithURL:(NSURL *)endpoint {
	CFHostRef host = (CFHostRef)[NSMakeCollectable(CFHostCreateWithName(kCFAllocatorDefault, (CFStringRef)[endpoint host])) autorelease];
	
	const AFNetworkTransportSignature *transportSignature = [[self class] transportSignatureForScheme:[endpoint scheme]];
	if ([endpoint port] != nil) transportSignature->port = [[endpoint port] intValue];
	
	const AFNetworkTransportPeerSignature peerSignature = {
		.host = host,
		.transport = transportSignature,
	};
	
	return [self initWithPeerSignature:&peerSignature];
}

- (id <AFTransportLayer>)initWithPeerSignature:(const AFNetworkTransportPeerSignature *)signature {	
	id <AFTransportLayer> lowerLayer = [[[[[self class] lowerLayerClass] alloc] initWithPeerSignature:signature] autorelease];
	return [self initWithLowerLayer:lowerLayer];
}

- (id <AFTransportLayer>)initWithNetService:(id <AFNetServiceCommon>)netService {
	id <AFTransportLayer> lowerLayer = [[[[[self class] lowerLayerClass] alloc] initWithNetService:netService] autorelease];
	return [self initWithLowerLayer:lowerLayer];
}

- (void)dealloc {
	self.lowerLayer = nil;
	self.transportInfo = nil;
	
	[super dealloc];
}

- (AFNetworkLayer *)lowerLayer {
	id value = nil;
	object_getInstanceVariable(self, "_lowerLayer", (void **)&value);
	return value;
}

- (void)setLowerLayer:(AFNetworkLayer *)layer {	
	id lowerLayer = nil;
	Ivar lowerLayerIvar = object_getInstanceVariable(self, "_lowerLayer", (void **)&lowerLayer);
	
	[layer retain];
	[lowerLayer release];
	lowerLayer = layer;
	
	object_setIvar(self, lowerLayerIvar, lowerLayer);
}

- (id)forwardingTargetForSelector:(SEL)selector {
	return self.lowerLayer;
}

- (BOOL)respondsToSelector:(SEL)selector {
	return ([super respondsToSelector:selector] || [[self forwardingTargetForSelector:selector] respondsToSelector:selector]);
}

- (AFPriorityProxy *)delegateProxy:(AFPriorityProxy *)proxy {	
	id delegate = nil;
	object_getInstanceVariable(self, "_delegate", (void **)&delegate);
	// Note: this intentionally doesn't use the accessor, I changed it before and left this comment here to warn me off next time.
	if (delegate == nil) return proxy;
	
	
	if (proxy == nil) proxy = [[[AFPriorityProxy alloc] init] autorelease];
	
	if ([delegate respondsToSelector:@selector(delegateProxy:)]) proxy = [(id)delegate delegateProxy:proxy];
	[proxy insertTarget:delegate atPriority:0];
	
	return proxy;
}

- (id)delegate {
	return [self delegateProxy:nil];
}

@end
