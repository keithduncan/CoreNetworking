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
	NSThread *_thread;
	NSObject *_target;
}

@end

@implementation NSObject (AFAdditions)

- (id)mainThreadProxy {
	return [self threadProxy:[NSThread mainThread]];
}

- (id)threadProxy:(NSThread *)thread {
	_AFObjectProxy *proxy = [[_AFObjectProxy alloc] autorelease];
	proxy->_thread = [thread retain];
	proxy->_target = [self retain];
	return proxy;
}

@end

#pragma mark -

@implementation _AFObjectProxy

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
