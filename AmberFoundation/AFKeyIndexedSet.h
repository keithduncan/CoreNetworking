//
//  AFKeyIndexedSet.h
//  Amber
//
//  Created by Keith Duncan on 04/02/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@class
	@abstract    This (controvertial!) class is designed to solve the problem of observing the content of a dictionary
	@discussion  Like its sibling class the AFKeyIndexedArray it maintains an internal dictionary index for an arbitrary key, thus providing O(1) access to members and dictionary like removal
*/
@interface AFKeyIndexedSet : NSMutableSet <NSFastEnumeration> {
	NSString *_keyPath;
	
	NSMutableSet *_objects;
	NSMutableDictionary *_index;
}

/*!
	@method
 */
- (id)initWithKeyPath:(NSString *)keyPath;

/*!
	@method
 */
@property (readonly, copy) NSString *keyPath;

/*!
	@method
 */
- (id)objectForIndexedValue:(id <NSCopying>)value;

/*!
	@method
 */
- (void)removeObjectForIndexedValue:(id <NSCopying>)value;

/*!
	@method
 */
- (void)refreshIndex;

@end
