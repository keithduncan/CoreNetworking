//
//  NSProxy+Additions.h
//  Amber
//
//  Created by Keith Duncan on 10/02/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSProxy (Additions)

/*!
 @method
 @abstract    This enumerates a collection performing sending any messages to all the objects in the collection
 @discussion  For cases where -makeObjectsPerformSelector:withObject: isn't flexible enough
 */

+ (id)collectionProxy:(id <NSObject, NSFastEnumeration>)collection; // Note: subsequent return values are undefined

@end
