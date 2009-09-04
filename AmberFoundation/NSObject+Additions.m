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

@interface _AFObjectProxy : NSProxy {
@public
	NSObject *_target;
}

@end

@implementation _AFObjectProxy

- (void)dealloc {
	[_target release];
	
	[super dealloc];
}

@end

#pragma mark -

/*!
	@brief
	This proxy is private, as such it doesn't implement anything beyond NSProxy.
 */

@interface _AFThreadProxy : _AFObjectProxy {
@public
	NSThread	*_thread;
	BOOL		_async;
}

@end

@implementation _AFThreadProxy

- (void)dealloc {
	if ([_thread isKindOfClass:[_AFThread class]]) [_thread cancel];
	[_thread release];
	
	[super dealloc];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	[invocation performSelector:@selector(invokeWithTarget:) onThread:_thread withObject:_target waitUntilDone:!_async];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	NSMethodSignature *signature = [_target methodSignatureForSelector:selector];
	if (_async)
		NSAssert1((strcmp([signature methodReturnType], @encode(void)) == 0), @"A method was request to be performed asynchronously on the main thread, but its return type is not void signature:%@", signature);
	return signature;
}

@end

#pragma mark -

@implementation NSObject (AFAdditions)

- (id)_threadProxy:(NSThread *)thread async:(BOOL)async;
{
	_AFThreadProxy *proxy = [[_AFThreadProxy alloc] autorelease];
	
	proxy->_target = [self retain];
	
	proxy->_thread = [thread retain];
	if ([thread isKindOfClass:[_AFThread class]]) [thread start];
	proxy->_async = async;
	
	return proxy;
}

- (id)syncThreadProxy:(NSThread *)thread;
{
	return [self _threadProxy:thread async:NO];	
}

- (id)asyncThreadProxy:(NSThread *)thread;
{
	return [self _threadProxy:thread async:YES];
}

- (id)syncMainThreadProxy {
	return [self _threadProxy:[NSThread mainThread] async:NO];
}

- (id)asyncMainThreadProxy {
	return [self _threadProxy:[NSThread mainThread] async:YES];
}

- (id)syncBackgroundThreadProxy {
	return [self _threadProxy:[[[_AFThread alloc] init] autorelease] async:NO];
}

- (id)asyncBackgroundThreadProxy {
	return [self _threadProxy:[[[_AFThread alloc] init] autorelease] async:YES];
}

- (id)protocolProxy:(Protocol *)protocol {
	return [[[AFProtocolProxy alloc] initWithTarget:self protocol:protocol] autorelease];
}

@end
