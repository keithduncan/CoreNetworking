//
//  AFPriorityProxy.m
//  Priority
//
//  Created by Keith Duncan on 22/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFPriorityProxy.h"

@implementation AFPriorityProxy

- (id)init {
	priorityMap = [[NSMapTable mapTableWithStrongToStrongObjects] retain];
	
	dispatchMap = [[NSMapTable alloc] initWithKeyOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality) valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality) capacity:/* Default CF collection capacity */ 3];
	
	return self;
}

- (void)dealloc {
	[priorityMap release];
	[dispatchOrder release];
	
	[dispatchMap release];
	
	[super dealloc];
}

- (BOOL)respondsToSelector:(SEL)selector {
	for (id currentDispatchTarget in dispatchOrder) {
		if (![currentDispatchTarget respondsToSelector:selector]) continue;
		
		return YES;
	}
	
	return NO;
}

/*!
	@method
	@abstract	This increments the priority value of each target by one
 */
- (void)_slidePriorityAtIndex:(NSUInteger)index {
	NSMapTable *newPriorityMap = [NSMapTable mapTableWithStrongToStrongObjects];
	
	for (id currentPriorityTarget in priorityMap) {
		NSNumber *currentPriorityIndex = NSMapGet(priorityMap, currentPriorityTarget);
		if ([currentPriorityIndex unsignedIntegerValue] < index) continue;
		
		NSMapInsert(newPriorityMap, currentPriorityTarget, [NSNumber numberWithUnsignedInteger:([currentPriorityIndex unsignedIntegerValue]+1)]);
	}
	
	[priorityMap release];
	priorityMap = [newPriorityMap retain];
}

/*!
	@method
	@abstract	This regenerates the relative priority based dispatch table
 */
- (void)_reorderDispatchTable {
	[dispatchOrder release];
	dispatchOrder = [[NSPointerArray pointerArrayWithWeakObjects] retain];
	[dispatchOrder setCount:[priorityMap count]];
	
	for (id currentPriorityKey in priorityMap) {
		[dispatchOrder replacePointerAtIndex:[(NSNumber *)NSMapGet(priorityMap, currentPriorityKey) unsignedIntegerValue] withPointer:currentPriorityKey];
	}
}

- (void)insertTarget:(id)target atPriority:(NSUInteger)index {
	if (target == nil) return;
	
	[self _slidePriorityAtIndex:index];
	NSMapInsert(priorityMap, target, [NSNumber numberWithUnsignedInteger:index]);
	[self _reorderDispatchTable];
}

- (void)_setDispatchedTargets:(NSMutableArray *)targets forSelector:(SEL)selector {
	if (targets != nil)
		NSMapInsert(dispatchMap, selector, targets);
	else
		NSMapRemove(dispatchMap, selector);
}

- (NSMutableArray *)_dispatchedTargetsForSelector:(SEL)selector {
	NSMutableArray *dispatchedTargets = NSMapGet(dispatchMap, selector);
	
	if (dispatchedTargets == nil) {
		dispatchedTargets = [NSMutableArray array];
		[self _setDispatchedTargets:dispatchedTargets forSelector:selector];
	}
	
	return dispatchedTargets;
}

- (id)_dispatchTargetForSelector:(SEL)selector {
	id dispatchTarget = nil;
	for (NSUInteger index = 0; index < [dispatchOrder count]; index++) {
		id currentDispatchTarget = [dispatchOrder pointerAtIndex:index];
		if (![currentDispatchTarget respondsToSelector:selector]) continue;
		
		BOOL currentDispatchTargetBeenMessaged = NO;
		for (id currentDispatchedTarget in [self _dispatchedTargetsForSelector:selector]) {
			if (currentDispatchedTarget == nil) continue;
			
			currentDispatchTargetBeenMessaged = (currentDispatchTarget == currentDispatchedTarget);
			if (!currentDispatchTargetBeenMessaged) break;
		}
		if (currentDispatchTargetBeenMessaged) continue;
		
		dispatchTarget = currentDispatchTarget;
		break;
	}
	
	return dispatchTarget;
}

- (void)_addDispatchedTarget:(id)target forSelector:(SEL)selector {
	NSMutableArray *dispatchedTargets = [self _dispatchedTargetsForSelector:selector];
	[dispatchedTargets addObject:target];
}

- (void)_removeDispatchedTarget:(id)target forSelector:(SEL)selector {
	NSMutableArray *dispatchedTargets = [self _dispatchedTargetsForSelector:selector];
	[dispatchedTargets removeObject:target];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	SEL selector = [invocation selector];
	id dispatchTarget = [self _dispatchTargetForSelector:selector];
	if (dispatchTarget == nil) return; // Note: this probably won't be nil as the -methodSignatureForSelector: caller will crash if it returns nil
	
	[self _addDispatchedTarget:dispatchTarget forSelector:selector];
	[invocation invokeWithTarget:dispatchTarget];
	[self _removeDispatchedTarget:dispatchTarget forSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return [[self _dispatchTargetForSelector:selector] methodSignatureForSelector:selector];
}

@end
