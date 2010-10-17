//
//  AFPriorityProxy.m
//  Priority
//
//  Created by Keith Duncan on 22/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkDelegateProxy.h"

@interface AFNetworkDelegateProxy ()
- (NSMutableArray *)_dispatchedTargetsForSelector:(SEL)selector;
@end

@implementation AFNetworkDelegateProxy

- (id)init {
	_dispatchOrder = [[NSMutableArray alloc] init];
	_dispatchMap = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)dealloc {
	[_dispatchOrder release];
	[_dispatchMap release];
	
	[super dealloc];
}

- (NSString *)description {
	NSMutableString *description = [[[super description] mutableCopy] autorelease];
	
	[description appendString:@" {"];
	[description appendFormat:@"\n\tDispatch Order: %@", _dispatchOrder, nil];
	[description appendString:@"\n}"];
	
	return description;
}

- (BOOL)respondsToSelector:(SEL)selector {
	for (id currentDispatchTarget in _dispatchOrder) {
		if (![currentDispatchTarget respondsToSelector:selector]) continue;
		if ([[self _dispatchedTargetsForSelector:selector] containsObject:currentDispatchTarget]) continue;
		return YES;
	}
	
	return NO;
}

- (void)insertTarget:(id)sender {
	[_dispatchOrder insertObject:sender atIndex:0];
}

- (void)appendTarget:(id)sender {
	[_dispatchOrder addObject:sender];
}

- (void)_setDispatchedTargets:(NSMutableArray *)targets forSelector:(SEL)selector {
	[_dispatchMap setValue:targets forKey:NSStringFromSelector(selector)];
}

- (NSMutableArray *)_dispatchedTargetsForSelector:(SEL)selector {
	NSMutableArray *dispatchedTargets = [_dispatchMap objectForKey:NSStringFromSelector(selector)];
	
	if (dispatchedTargets == nil) {
		dispatchedTargets = [NSMutableArray array];
		[self _setDispatchedTargets:dispatchedTargets forSelector:selector];
	}
	
	return dispatchedTargets;
}

- (id)_dispatchTargetForSelector:(SEL)selector {
	id dispatchTarget = nil;
	for (NSUInteger index = 0; index < [_dispatchOrder count]; index++) {
		id currentDispatchTarget = [_dispatchOrder objectAtIndex:index];
		
		if (![currentDispatchTarget respondsToSelector:selector]) continue;
		if ([[self _dispatchedTargetsForSelector:selector] containsObject:currentDispatchTarget]) continue;
		
		return currentDispatchTarget;
	}
	
	return nil;
}

- (void)_addDispatchedTarget:(id)target forSelector:(SEL)selector {
	NSMutableArray *dispatchedTargets = [self _dispatchedTargetsForSelector:selector];
	[dispatchedTargets addObject:target];
}

- (void)_removeDispatchedTarget:(id)target forSelector:(SEL)selector {
	NSMutableArray *dispatchedTargets = [self _dispatchedTargetsForSelector:selector];
	[dispatchedTargets removeObject:target];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return [[self _dispatchTargetForSelector:selector] methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	SEL selector = [invocation selector];
	id dispatchTarget = [self _dispatchTargetForSelector:selector];
	
	if (dispatchTarget == nil) {
		[NSException raise:NSInternalInconsistencyException format:@"%s, cannot dispatch to a nil target", __PRETTY_FUNCTION__, nil];
		return;
	}
	
	[self _addDispatchedTarget:dispatchTarget forSelector:selector];
	[invocation invokeWithTarget:dispatchTarget];
	[self _removeDispatchedTarget:dispatchTarget forSelector:selector];
}

@end
