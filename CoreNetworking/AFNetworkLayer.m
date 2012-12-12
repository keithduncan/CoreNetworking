//
//  AFNetworkLayer.m
//  Amber
//
//  Created by Keith Duncan on 04/05/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkLayer.h"

#import <objc/runtime.h>

#import "AFNetworkDelegateProxy.h"

@interface AFNetworkLayer ()
@property (readwrite, retain, nonatomic) AFNetworkLayer *lowerLayer;
@property (readwrite, retain, nonatomic) NSMutableDictionary *userInfo;
@end

@implementation AFNetworkLayer

@synthesize lowerLayer = _lowerLayer;
@synthesize delegate=_delegate;
@synthesize userInfo=_userInfo;

+ (Class)lowerLayerClass {
	return Nil;
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_userInfo = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (id)initWithLowerLayer:(id <AFNetworkTransportLayer>)layer {
	self = [self init];
	if (self == nil) return nil;
	
	_lowerLayer = [layer retain];
	_lowerLayer.delegate = (id)self;
	
	return self;
}

- (AFNetworkLayer *)initWithTransportSignature:(AFNetworkSignature)signature {
	AFNetworkLayer *lowerLayer = [[[(id)[[self class] lowerLayerClass] alloc] initWithTransportSignature:signature] autorelease];
	return [self initWithLowerLayer:(id)lowerLayer];
}

- (void)dealloc {
	[_lowerLayer release];
	[_userInfo release];
	
	[super dealloc];
}

- (id)forwardingTargetForSelector:(SEL)selector {
	return self.lowerLayer;
}

- (BOOL)respondsToSelector:(SEL)selector {
	return ([super respondsToSelector:selector] || [[self forwardingTargetForSelector:selector] respondsToSelector:selector]);
}

- (AFNetworkDelegateProxy *)delegateProxy:(AFNetworkDelegateProxy *)proxy {	
	if (_delegate == nil) {
		return proxy;
	}
	
	if (proxy == nil) {
		proxy = [[[AFNetworkDelegateProxy alloc] init] autorelease];
	}
	
	if ([_delegate respondsToSelector:@selector(delegateProxy:)]) {
		proxy = [(id)_delegate delegateProxy:proxy];
	}
	
	[proxy insertTarget:_delegate];
	
	return proxy;
}

- (id)delegate {
	return [self delegateProxy:nil];
}

- (NSDictionary *)_concatenatedUserInfo {
	NSMutableDictionary *transportInfo = [NSMutableDictionary dictionary];
	
	NSMutableArray *layers = [NSMutableArray array];
	for (id layer = self; layer != nil; layer = [layer lowerLayer]) [layers insertObject:layer atIndex:0];
	
	for (AFNetworkLayer *currentLayer in layers) {
		// Note: the direct ivar access is important
		[transportInfo setValuesForKeysWithDictionary:currentLayer->_userInfo];
	}
	
	return transportInfo;
}

- (id)userInfoValueForKey:(id <NSCopying>)key {
	return [[self _concatenatedUserInfo] objectForKey:(id)key];
}

- (void)setUserInfoValue:(id)value forKey:(id <NSCopying>)key {
	[_userInfo setValue:value forKey:(id)key];
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	[self.lowerLayer scheduleInRunLoop:runLoop forMode:mode];
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	[self.lowerLayer unscheduleFromRunLoop:runLoop forMode:mode];
}

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	[self.lowerLayer scheduleInQueue:queue];
}

#endif

- (void)networkLayerDidOpen:(id)layer {
	if (layer == self.lowerLayer) {
		layer = (id)self;
	}
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidOpen:)]) {
		[self.delegate networkLayerDidOpen:layer];
	}
}

- (void)networkLayerDidClose:(id)layer {
	if (layer == self.lowerLayer) {
		layer = (id)self;
	}
	
	if ([self.delegate respondsToSelector:@selector(networkLayerDidClose:)]) {
		[self.delegate networkLayerDidClose:layer];
	}
}

- (void)networkLayer:(id <AFNetworkTransportLayer>)layer didReceiveError:(NSError *)error {
	if (layer == self.lowerLayer) {
		layer = (id)self;
	}
	
	[self.delegate networkLayer:layer didReceiveError:error];
}

@end
