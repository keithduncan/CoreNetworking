//
//  NSObject+Additions.m
//  Sparkle2
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSObject+Additions.h"

@interface NSObject (PrivateAdditions)
- (id)threadProxy:(NSThread *)thread;
@end

@interface _KDObjectProxy : NSProxy {
@public
	NSThread *_thread;
	id <NSObject> *_target;
}

@end

@implementation NSObject (Additions)

- (id)mainThreadProxy {
	return [self threadProxy:[NSThread mainThread]];
}

@end

@implementation NSObject (PrivateAdditions)

- (id)threadProxy:(NSThread *)thread {
	_KDObjectProxy *proxy = [[_KDObjectProxy alloc] autorelease];
	proxy->_thread = [thread retain];
	proxy->_target = [self retain];
	return proxy;
}

@end

#pragma mark -

@implementation _KDObjectProxy

- (void)dealloc {
	[_thread release];
	[_target release];
	
	[super dealloc];
}

- (void)forwardInvocation:(NSInvocation *)invocation {	
	[invocation performSelector:@selector(invokeWithTarget:) onThread:_thread withObject:_target waitUntilDone:(_thread == [NSThread mainThread])];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return [_target methodSignatureForSelector:selector];
}

@end
