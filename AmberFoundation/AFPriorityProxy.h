//
//  AFPriorityProxy.h
//  Priority
//
//  Created by Keith Duncan on 22/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AFPriorityProxy : NSProxy {
	NSMapTable *priorityMap;
	NSPointerArray *dispatchOrder; // this is generated from the map and is relative whereas the priorityMap is absolute
	
	NSMapTable *dispatchMap; // keyed by selector to a pointer array of dispatch targets
}

/*!
 @method
 @abstract	Unlike the superclass which doesn't specify an instantiator this class does
 */
- (id)init;

/*!
 @method
 @abstract	Target priority is enumerated low to high
 @discussion	It is highly recommended that you insert a catch-all object at the lowest priority (zero), otherwise message dispatch will throw an unrecognised selector exception
 */
- (void)insertTarget:(id)target atPriority:(NSUInteger)index;

@end
