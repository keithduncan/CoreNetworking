//
//  AFKeyPathProxy.m
//  Key-Path Proxy
//
//  Created by Keith Duncan on 24/04/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFKeyPathAccumulatorProxy.h"

#import <objc/runtime.h>

@interface AFKeyPathAccumulatorProxy ()
- (id)_currentTarget;
@property (copy) NSString *prependOperator;
@end

@interface AFKeyPathAccumulatorProxy (Private)
- (NSString *)_prependKeyPathOperator:(NSString *)keyPath;
@end

@implementation AFKeyPathAccumulatorProxy

@synthesize currentTarget=_currentTarget;
@synthesize prependOperator=_prependOperator;

static NSString *AFKeyPathProxyCollectionOperators[] = {
	@"avg",
	@"count",
	@"distinctUnionOfArrays",
	@"distinctUnionOfObjects",
	@"distinctUnionOfSets",
	@"max",
	@"min",
	@"sum",
	@"unionOfArrays",
	@"unionOfObjects",
	@"unionOfSets",
};

static BOOL _AFKeyPathProxyKeyIsOperator(NSString *key) {
	for (NSUInteger operatorIndex = 0; operatorIndex < sizeof(AFKeyPathProxyCollectionOperators)/sizeof(NSString *); operatorIndex++) {
		if ([key rangeOfString:AFKeyPathProxyCollectionOperators[operatorIndex] options:(NSAnchoredSearch | NSBackwardsSearch)].length == 0) continue;
		return YES;
	}
	
	return NO;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	NSString *keyPath = NSStringFromSelector([invocation selector]);
	BOOL invokeKeyPath = YES;
	
	if (_AFKeyPathProxyKeyIsOperator(keyPath)) {
		self.prependOperator = [NSString stringWithFormat:@"@%@", keyPath, nil];
		invokeKeyPath = NO;
	}
	
	if (invokeKeyPath) {
		keyPath = [self _prependKeyPathOperator:keyPath];
		
		[invocation setTarget:[self _currentTarget]];
		[invocation setSelector:@selector(valueForKeyPath:)];
		[invocation setArgument:&keyPath atIndex:2];
		[invocation invoke];
		
		id result = nil;
		[invocation getReturnValue:&result];
		self.currentTarget = result;
	}
	
	[invocation setReturnValue:&self];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return [[self _currentTarget] methodSignatureForSelector:@selector(valueForKey:)];
}

- (id)valueForUndefinedKey:(NSString *)keyPath {
	if (_AFKeyPathProxyKeyIsOperator(keyPath)) {
		self.prependOperator = keyPath;
		return self;
	}
	
	keyPath = [self _prependKeyPathOperator:keyPath];
	
	self.currentTarget = [[self _currentTarget] valueForKeyPath:keyPath];
	return self;
}

- (void)dealloc {
	self.currentTarget = nil;
	self.prependOperator = nil;
	
	[super dealloc];
}

- (id)_currentTarget {
	id value = nil;
	object_getInstanceVariable(self, "_currentTarget", (void **)&value);
	return value;
}

- (id)currentTarget {
	id value = [self _currentTarget];
	
	if (self.prependOperator != nil) {
		value = [value valueForKey:self.prependOperator];
	}
	
	return value;
}

@end

@implementation AFKeyPathAccumulatorProxy (Private)

- (NSString *)_prependKeyPathOperator:(NSString *)keyPath {
	if (self.prependOperator != nil) {
		keyPath = [[NSArray arrayWithObjects:self.prependOperator, keyPath, nil] componentsJoinedByString:@"."];
		self.prependOperator = nil;
	}
	
	return keyPath;
}

@end
