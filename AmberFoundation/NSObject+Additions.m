//
//  NSObject+Additions.m
//  Amber
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007. All rights reserved.
//

#import "NSObject+Additions.h"

#import <objc/runtime.h>
#import <pthread.h>

#import "AFProtocolProxy.h"

@interface _AFThread : NSThread

+ (id)backgroundRunLoop;

@end

@implementation _AFThread

+ (id)backgroundRunLoop {
	static _AFThread *_sharedBackgroundThread;
	@synchronized ([_AFThread class]) {
		if (_sharedBackgroundThread == nil) {
			_sharedBackgroundThread = [[_AFThread alloc] init];
			
			[_sharedBackgroundThread setName:@"com.thirty-three.amberfoundation.backgroundrunloop"];
			
			[_sharedBackgroundThread start];
		}
	}
	return _sharedBackgroundThread;
}

static void _AFBackgroundRunLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, NSAutoreleasePool **poolRef) {
	[*poolRef drain];
	*poolRef = [NSAutoreleasePool new];
}

- (void)main {
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
#warning this pool isn't drained inside the loop, it will accumulate objects
	
	pthread_setname_np([[[NSThread currentThread] name] UTF8String]);
	
	CFRunLoopObserverContext context = {0};
	CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 0, (CFRunLoopObserverCallBack)_AFBackgroundRunLoopObserverCallBack, (void *)&pool);
	
	CFRunLoopRun();
	
	[pool drain];
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
	\brief
	This proxy is private, as such it doesn't implement anything beyond NSProxy.
 */

@interface _AFThreadProxy : _AFObjectProxy {
 @public
	NSThread *_thread;
	BOOL _synchronous;
}

@end

@implementation _AFThreadProxy

- (void)dealloc {
	[_thread release];
	
	[super dealloc];
}

- (void)forwardInvocation:(NSInvocation *)invocation {	
	if ([_thread isEqual:[NSThread currentThread]]) {
		[invocation invokeWithTarget:_target];
		return;
	}
	
	// If we don't retain the arguments, they're likely release when the local pool is popped, while |_target| is using them on |_thread|
	if (!_synchronous) [invocation retainArguments];
	
	[invocation performSelector:@selector(invokeWithTarget:) onThread:_thread withObject:_target waitUntilDone:_synchronous];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	NSMethodSignature *signature = [_target methodSignatureForSelector:selector];
	if (!_synchronous) NSAssert1((strcmp([signature methodReturnType], @encode(void)) == 0), @"A method was request to be performed asynchronously, but its return type is not void signature: %@", signature);
	return signature;
}

@end

#pragma mark -

@implementation NSObject (AFAdditions)

- (id)threadProxy:(NSThread *)thread synchronous:(BOOL)waitUntilDone {
	_AFThreadProxy *proxy = [[_AFThreadProxy alloc] autorelease];
	
	proxy->_target = [self retain];
	
	proxy->_thread = [thread retain];
	proxy->_synchronous = waitUntilDone;
	
	return proxy;
}

- (id)syncMainThreadProxy {
	return [self threadProxy:[NSThread mainThread] synchronous:YES];
}

- (id)asyncMainThreadProxy {
	return [self threadProxy:[NSThread mainThread] synchronous:NO];
}

- (id)syncBackgroundThreadProxy {
	return [self threadProxy:[_AFThread backgroundRunLoop] synchronous:YES];
}

- (id)asyncBackgroundThreadProxy {
	return [self threadProxy:[_AFThread backgroundRunLoop] synchronous:NO];
}

- (id)protocolProxy:(Protocol *)protocol {
	return [[[AFProtocolProxy alloc] initWithTarget:self protocol:protocol] autorelease];
}

@end
