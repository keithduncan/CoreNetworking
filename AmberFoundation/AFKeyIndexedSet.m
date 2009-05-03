//
//  AFKeyIndexedSet.m
//  Amber
//
//  Created by Keith Duncan on 04/02/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "AFKeyIndexedSet.h"

@interface AFKeyIndexedSet ()
@property (retain) NSMutableSet *objects;
@property (retain) NSMutableDictionary *index;
@end

@implementation AFKeyIndexedSet

@synthesize keyPath=_keyPath;
@synthesize objects=_objects, index=_index;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_objects = [[NSMutableSet alloc] init];
	_index = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (id)initWithKeyPath:(NSString *)keyPath {
	self = [self init];
	if (self == nil) return nil;
	
	NSParameterAssert(keyPath != nil);
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
	return [NSString stringWithFormat:@"%@ index: %p \n%@\n", [super description], self.index, self.index, nil];
}

- (NSUInteger)count {
	return [self.objects count];
}

- (id)member:(id)object {
	return [self.objects member:object];
}

- (NSEnumerator *)objectEnumerator {
	return [self.objects objectEnumerator];
}

- (void)addObject:(id)object {
	[self.objects addObject:object];
	
	id key = [object valueForKeyPath:self.keyPath];
	NSAssert([self.index objectForKey:key] == nil, ([NSString stringWithFormat:@"%s, adding another object for key %@", __PRETTY_FUNCTION__, key, nil]));
	[self.index setObject:object forKey:key];
}

- (void)removeObject:(id)object {
	if ([self member:object] == nil) return; // Note: this is to check that removing an object that is not a member, won't actually remove an object from the index
	
	[self.index removeObjectForKey:[object valueForKeyPath:self.keyPath]];
	[self.objects removeObject:object];
}

- (id)objectForIndexedValue:(id <NSCopying>)value {
	return [self.index objectForKey:value];
}

- (NSSet *)objectsForIndexedValues:(NSSet *)values {
	NSMutableSet *objects = [NSMutableSet setWithCapacity:[values count]];
	
	for (id indexedValue in values)
		[objects addObject:[self objectForIndexedValue:indexedValue]];
	
	return objects;
}

- (void)removeObjectForIndexedValue:(id <NSCopying>)value {
	id object = [self.index objectForKey:value];
	if (object == nil) return;
	
	[self.objects removeObject:object];
	[self.index removeObjectForKey:value];
}

- (void)refreshIndex {
	[self.index removeAllObjects];
	
	for (id currentObject in self.objects) [self.index setObject:currentObject forKey:[currentObject valueForKeyPath:self.keyPath]];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
	return [self.objects countByEnumeratingWithState:state objects:stackbuf count:len];
}

@end
