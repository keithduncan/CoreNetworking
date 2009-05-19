//
//  NSObject+Additions.m
//  Amber
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "NSObject+Additions.h"

#import <objc/runtime.h>

#import "AFProtocolProxy.h"

@interface _AFThread : NSThread

@end

@implementation _AFThread

- (void)main {
	do {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantPast]];
	} while (![self isCancelled]);
}

@end

#pragma mark -

/*!
	@brief
	This proxy is private, as such it doesn't implement anything beyond NSProxy.
 */
@interface _AFThreadProxy : NSProxy {
 @public
	id _target;
	NSThread *_thread;
}

@end

@implementation _AFThreadProxy

- (void)dealloc {
	[_target release];
	
	if ([_thread isKindOfClass:[_AFThread class]]) [_thread cancel];
	[_thread release];
	
	[super dealloc];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	[invocation performSelector:@selector(invokeWithTarget:) onThread:_thread withObject:_target waitUntilDone:[_thread isEqual:[NSThread mainThread]]];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return [_target methodSignatureForSelector:selector];
}

@end

#pragma mark -

@implementation NSObject (AFAdditions)

- (id)mainThreadProxy {
	return [self threadProxy:[NSThread mainThread]];
}

- (id)backgroundThreadProxy {
	return [self threadProxy:[[[_AFThread alloc] init] autorelease]];
}

- (id)threadProxy:(NSThread *)thread {
	_AFThreadProxy *proxy = [[_AFThreadProxy alloc] autorelease];
	
	proxy->_target = [self retain];
	
	proxy->_thread = [thread retain];
	if ([thread isKindOfClass:[_AFThread class]]) [thread start];
	
	return proxy;
}

- (id)protocolProxy:(Protocol *)protocol {
	return [[[AFProtocolProxy alloc] initWithTarget:self protocol:protocol] autorelease];
}

@end
