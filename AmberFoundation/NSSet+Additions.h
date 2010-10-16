//
//  NSSet+Additions.h
//  Amber
//
//  Created by Keith Duncan on 05/04/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSSet (AFAdditions)

/*!
	\return
	A copy of the receiver with the provided objects appended to the collection.
 */
- (NSSet *)setByAddingObjects:(id)firstObject, ... NS_REQUIRES_NIL_TERMINATION;

@end

