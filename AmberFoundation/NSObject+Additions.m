//
//  NSObject+Additions.m
//  Sparkle2
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007 thirty-three. All rights reserved.
//

#import "NSObject+Additions.h"

#import <objc/runtime.h>

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
	[invocation performSelector:@selector(invokeWithTarget:) onThread:_thread withObject:_target waitUntilDone:([_thread isEqual:[NSThread mainThread]])];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return [_target methodSignatureForSelector:selector];
}

@end

@interface _AFOptionalProxy : _AFObjectProxy {
 @public
	Protocol *_protocol;
}

@end

@implementation _AFOptionalProxy

- (void)forwardInvocation:(NSInvocation *)invocation {
	if (![_target respondsToSelector:[invocation selector]]) return;
	[invocation invokeWithTarget:_target];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	if ([_target respondsToSelector:selector]) return [_target methodSignatureForSelector:selector];
	
	// Note: isRequiredMethod can be no, because if it's required and not implemented the compiler will issue a warning
	struct objc_method_description method = protocol_getMethodDescription(_protocol, selector, /* isRequiredMethod */ NO, /* isInstanceMethod */ YES);
#warning isInstanceMethod should be dynamic
	
	return [NSMethodSignature signatureWithObjCTypes:method.types];
}

@end

#pragma mark -

@implementation NSObject (AFAdditions)

- (id)mainThreadProxy {
	return [self threadProxy:[NSThread mainThread]];
}

- (id)backgroundThreadProxy {
	return [self threadProxy:[[[NSThread alloc] init] autorelease]];
}

- (id)threadProxy:(NSThread *)thread {
	_AFThreadProxy *proxy = [[_AFThreadProxy alloc] autorelease];
	proxy->_target = [self retain];
	proxy->_thread = [thread retain];
	return proxy;
}

- (id)protocolProxy:(Protocol *)protocol {
	_AFOptionalProxy *proxy = [[_AFOptionalProxy alloc] autorelease];
	proxy->_target = [self retain];
	proxy->_protocol = protocol;
	return proxy;
}

@end
