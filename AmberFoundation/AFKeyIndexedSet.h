//
//  AFKeyIndexedSet.h
//  Amber
//
//  Created by Keith Duncan on 04/02/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@brief
	This (controvertial!) class is designed to solve the problem of observing the content of a dictionary.
 
	See <tt>AFKeyIndexedArray</tt> for more details, the two classes are nearly identical.
 
	@detail
	Like its sibling class the AFKeyIndexedArray it maintains an internal dictionary index for an
	arbitrary key, thus providing O(1) access to members and dictionary like removal.
*/
@interface AFKeyIndexedSet : NSMutableSet <NSFastEnumeration> {
	NSString *_keyPath;
	
	NSMutableSet *_objects;
	NSMutableDictionary *_index;
}

/*
	@brief
	Designated Initialiser.
 
	@param |keyPath| is copied.
 */
- (id)initWithKeyPath:(NSString *)keyPath;

@property (readonly, copy) NSString *keyPath;

- (id)objectForIndexedValue:(id <NSCopying>)value;

- (NSSet *)objectsForIndexedValues:(NSSet *)values;

- (void)removeObjectForIndexedValue:(id <NSCopying>)value;

- (void)refreshIndex;

@end
