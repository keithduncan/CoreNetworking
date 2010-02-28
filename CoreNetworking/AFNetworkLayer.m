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

- (AFNetworkLayer *)initWithTransportSignature:(AFNetworkTransportSignature)signature {
	AFNetworkLayer *lowerLayer = [[[(id)[[self class] lowerLayer] alloc] initWithTransportSignature:signature] autorelease];
	return [self initWithLowerLayer:(id)lowerLayer];
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

- (NSDictionary *)transportInfo {
	NSMutableDictionary *transportInfo = [NSMutableDictionary dictionary];
	
	NSMutableArray *layers = [NSMutableArray array];
	for (id layer = self; layer != nil; layer = [layer lowerLayer]) [layers insertObject:layer atIndex:0];
	
	for (AFNetworkLayer *currentLayer in [layers reverseObjectEnumerator]) {
		// Note: the direct ivar access is important
		[transportInfo setValuesForKeysWithDictionary:currentLayer->_transportInfo];
	}
	
	return transportInfo;
}

- (id)valueForUndefinedKey:(NSString *)key {
	return [_transportInfo valueForKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
	[_transportInfo setValue:value forKey:key];
}

- (void)layerDidOpen:(id)layer {
	if (layer == self.lowerLayer) layer = self;
	
	if ([self.delegate respondsToSelector:_cmd])
		[self.delegate layerDidOpen:layer];
}

- (void)layerDidClose:(id)layer {
	if (layer == self.lowerLayer) layer = self;
	
	if ([self.delegate respondsToSelector:_cmd])
		[self.delegate layerDidClose:layer];
}

@end
