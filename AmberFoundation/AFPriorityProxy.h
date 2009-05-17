//
//  AFPriorityProxy.h
//  Priority
//
//  Created by Keith Duncan on 22/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@brief
	This proxy class allows for more complex message routing. It can be used to
	create a delegate-chain or an improved responder chain.
 
	@detail
	It is recursive-safe, whilst a routed method is on the stack it won't be called again.
	Calling an in-dispatch selector will route it to the next target in the list.
	It is highly recommended that you either insert a catch-all object at the lowest priority (zero),
	or wrap this proxy in an optional proxy, otherwise message dispatch WILL throw an
	unrecognised selector exception if no object responds.
 */
@interface AFPriorityProxy : NSProxy {
	NSMapTable *priorityMap;
	NSPointerArray *dispatchOrder; // this is generated from the map and is relative whereas the priorityMap is absolute
	
	NSMapTable *dispatchMap; // keyed by selector to a pointer array of dispatch targets
}

/*!
	@brief
	Designated Initialiser.
 */
- (id)init;

/*!
	@brief
	Target priority is enumerated low to high.
	Targets are not retained, as they will tend to be delegates or self.
 */
- (void)insertTarget:(id)target atPriority:(NSUInteger)index;

@end
