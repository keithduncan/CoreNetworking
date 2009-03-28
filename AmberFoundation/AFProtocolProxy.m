//
//  AFProtocolProxy.m
//  Priority
//
//  Created by Keith Duncan on 22/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFProtocolProxy.h"

#import <objc/runtime.h>

@implementation AFProtocolProxy

- (id)initWithTarget:(id)target protocol:(Protocol *)protocol {
	_target = [target retain];
	_protocol = protocol;
	
	return self;
}

- (void)dealloc {
	[_target release];
	
	[super dealloc];
}

- (BOOL)respondsToSelector:(SEL)selector {
	return ([self methodSignatureForSelector:selector] != nil);
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	if (_target == nil || ![_target respondsToSelector:[invocation selector]]) return;
	
	[invocation invokeWithTarget:_target];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {	
	for (SInt8 mask = 0; mask < 4; mask++) {
		struct objc_method_description description = protocol_getMethodDescription(_protocol, selector, (mask & 0x01), (mask & 0x02));
		if (description.name == NULL && description.types == NULL) continue;
		
		return [NSMethodSignature signatureWithObjCTypes:description.types];
	}
	
	return nil;
}

@end
