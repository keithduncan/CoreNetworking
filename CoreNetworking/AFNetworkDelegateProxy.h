//
//  AFPriorityProxy.h
//  Priority
//
//  Created by Keith Duncan on 22/03/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\brief
	Allows for complex message routing. Can be used to create a delegate-chain, or an improved responder chain which may be useful for a view controller architecture.
	
	\details
	Recursive-safe, whilst a selector is on the stack it won't be called again on the same target twice. Calling an in-dispatch selector will route it to the next target in the list.
	It is highly recommended that you either insert a catch-all object at the lowest priority (zero), or wrap this proxy in an optional proxy, otherwise message dispatch WILL throw an unrecognised selector exception if no object responds.
 */
@interface AFNetworkDelegateProxy : NSProxy {
 @private
	// this is generated from the map and is relative whereas the priorityMap is absolute
	NSMutableArray *_dispatchOrder;
	// keyed by selector to a pointer array of dispatch targets
	NSMutableDictionary *_dispatchMap;
}

/*!
	\brief
	Designated Initialiser.
 */
- (id)init;

/*!
	\brief
	Target priority is enumerated low to high, this inserts a target at the lowest index i.e. the first to be called
 */
- (void)insertTarget:(id)sender;

/*!
	\brief
	Target priority is enumerated low to high, this appends a target highest index i.e. the last to be called
 */
- (void)appendTarget:(id)sender;

@end
