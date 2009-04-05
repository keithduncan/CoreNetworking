//
//  AFKeyIndexedArray.h
//  Amber
//
//  Created by Keith Duncan on 28/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@class
	@abstract	This class is much like the OrderedDictionary written by Matt Gallager <a href="http://cocoawithlove.com">cocoawithlove.com</a>
				but instead the primary interface is an array. It maintains an index of the objects it contains 
				using <tt>-valueForKeyPath:</tt> on the objects added to the collection.
	@discussion	Combining an dictionary with an NSArray subclass allows O(1) access to elements without having to
				iterate the collection. The objects returned from <tt>-valueForKeyPath:</tt> for the provided 
				keypath must implement the &lt;NSCoding&gt; protocol, as they are used for keying the object in the
				dictionary index. Equally, the property identified by |keyPath| should be immutable, the collection
				doesn't observe it for changes for performance reasons. If you do change an indexed value you can
				force the collection to reindex using the <tt>-refreshIndex</tt> method.
 */
@interface AFKeyIndexedArray : NSMutableArray {
	NSString *_keyPath;
	
	NSMutableArray *_objects;
	NSMutableDictionary *_index;
}

/*!
	@method
	@param		The |keyPath| is copied.
 */
- (id)initWithKeyPath:(NSString *)keyPath;

/*!
	@property
 */
@property (readonly, copy) NSString *keyPath;

/*!
	@method
	@abstract	This searches the index for <tt>-objectForKey:</tt> passing the |value| as an argument.
 */
- (id)objectForIndexedValue:(id <NSCopying>)value;

/*!
	@method
 */
- (void)removeObjectForIndexedValue:(id <NSCopying>)value;

/*!
	@method
	@abstract	This method discards the old index and recreates it from scratch
	@discussion	The method should be used if you change an indexed value.
 */
- (void)refreshIndex;

@end
