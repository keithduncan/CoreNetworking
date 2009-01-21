//
//  NSObject+Additions.m
//  Sparkle2
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSObject+Additions.h"

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

@interface _AFThreadProxy : _AFObjectProxy {
@public
	NSThread *_thread;
}

@end

@implementation _AFThreadProxy

- (void)dealloc {
	[_thread release];
	
	[super dealloc];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	[invocation performSelector:@selector(invokeWithTarget:) onThread:_thread withObject:_target waitUntilDone:(_thread == [NSThread mainThread])];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return [_target methodSignatureForSelector:selector];
}

@end

@interface _AFOptionalProxy : _AFObjectProxy {
@public
	
}
@end

@implementation _AFOptionalProxy

- (void)forwardInvocation:(NSInvocation *)invocation {
	if (![_target respondsToSelector:[invocation selector]]) return;
	[invocation invokeWithTarget:_target];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return ([_target respondsToSelector:selector]) ? [_target methodSignatureForSelector:selector] : [NSMethodSignature signatureWithObjCTypes:"v@:"];
}

@end

#pragma mark -

@implementation NSObject (AFAdditions)

- (id)mainThreadProxy {
	return [self threadProxy:[NSThread mainThread]];
}

- (id)threadProxy:(NSThread *)thread {
	_AFThreadProxy *proxy = [[_AFThreadProxy alloc] autorelease];
	proxy->_thread = [thread retain];
	proxy->_target = [self retain];
	return proxy;
}

- (id)optionalProxy {
	_AFOptionalProxy *proxy = [[_AFOptionalProxy alloc] autorelease];
	proxy->_target = [self retain];
	return proxy;
}

@end

