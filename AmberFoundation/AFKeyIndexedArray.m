//
//  AFKeyIndexedArray.m
//  Amber
//
//  Created by Keith Duncan on 28/01/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFKeyIndexedArray.h"

@interface AFKeyIndexedArray ()
@property (readwrite, copy) NSString *keyPath;
@property (retain) NSMutableArray *objects;
@property (retain) NSMutableDictionary *index;
@end

@implementation AFKeyIndexedArray

@synthesize keyPath=_keyPath;
@synthesize objects=_objects, index=_index;

- (id)init {
	self = [super init];
	
	_objects = [[NSMutableArray alloc] init];
	_index = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (id)initWithKeyPath:(NSString *)keyPath {
	self = [super init];
	
	NSParameterAssert(key != nil);
	_keyPath = [keyPath copy];
	
	return self;
}

- (void)dealloc {
	[_keyPath release];
	
	[_objects release];
	[_index release];
	
	[super dealloc];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"%@ index: %p \n{\n%@\n}", ]), [super description], self.index, self.index, nil];
}

- (NSUInteger)count {
	return [self.objects count];
}

- (id)objectAtIndex:(NSUInteger)index {
	return [self.objects objectAtIndex:index];
}

- (void)addObject:(id)object {
	[self.objects addObject:object];
	
	id key = [object valueForKeyPath:self.keyPath];
	NSAssert([self.index objectForKey:key] == nil, ([NSString stringWithFormat:@"%s, adding another object for key %@", __PRETTY_FUNCTION__, key, nil]));
	[self.index setObject:object forKey:key];
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index {
	[self.objects insertObject:object atIndex:index];
	
	id key = [object valueForKeyPath:self.keyPath];
	NSAssert([self.index objectForKey:key] == nil, ([NSString stringWithFormat:@"%s, adding another object for key %@", __PRETTY_FUNCTION__, key, nil]));
	[self.index setObject:object forKey:key];
}

- (void)removeLastObject {
	[self removeObjectAtIndex:[self count]];
}

- (void)removeObjectAtIndex:(NSUInteger)index {
	id object = [self.objects objectAtIndex:index];
	[self.index removeObjectForKey:[object valueForKeyPath:self.keyPath]];
	[self.objects removeObjectAtIndex:index];
}

- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)object {
	id oldObject = [self.objects objectAtIndex:index];
	[self.index removeObjectForKey:[oldObject valueForKeyPath:self.keyPath]];
	
	[self.objects replaceObjectAtIndex:index withObject:object];
	[self.index setObject:object forKey:[object valueForKeyPath:self.keyPath]];
}

- (id)objectForIndexedValue:(id <NSCopying>)value {
	return [self.index objectForKey:value];
}

- (void)removeObjectForIndexedValue:(id <NSCopying>)value {
	id object = [self.index objectForKey:value];
	[self.index removeObjectForKey:value];
	[self.objects removeObject:object];
}

- (void)refreshIndex {
	[self.index removeAllObjects];
	
	for (id currentObject in self.objects) [self.index setObject:currentObject forKey:[currentObject valueForKeyPath:self.keyPath]];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
	return [self.objects countByEnumeratingWithState:state objects:stackbuf count:len];
}

@end
