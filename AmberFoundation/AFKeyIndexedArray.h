//
//  AFKeyIndexedArray.h
//  Amber
//
//  Created by Keith Duncan on 28/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@brief	This class is much like the OrderedDictionary written by Matt Gallager <a href="http://cocoawithlove.com">cocoawithlove.com</a>
			but instead the primary interface is an array. It maintains an index of the objects it contains 
			using <tt>-valueForKeyPath:</tt> on the objects added to the collection.
	@detail	Combining an dictionary with an NSArray subclass allows O(1) access to elements without having to
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
	@param	|keyPath| is copied.
 */
- (id)initWithKeyPath:(NSString *)keyPath;


@property (readonly, copy) NSString *keyPath;

/*!
	@brief	This searches the index for <tt>-objectForKey:</tt> passing the |value| as an argument.
 */
- (id)objectForIndexedValue:(id <NSCopying>)value;


- (void)removeObjectForIndexedValue:(id <NSCopying>)value;

/*!
	@brief	This method discards the old index and recreates it from scratch.
	@detail	The method should be used if you change an indexed value.
 */
- (void)refreshIndex;

@end
