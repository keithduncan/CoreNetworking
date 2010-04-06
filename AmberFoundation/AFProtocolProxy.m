//
//  AFProtocolProxy.m
//  Priority
//
//  Created by Keith Duncan on 22/03/2009.
//  Copyright 2009. All rights reserved.
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

/*!
	@brief	This is a recursive function to find a method signature in a protocol and its conformed protcols
 */
static NSMethodSignature *AFProtcolGetMethodSignature(SEL selector, Protocol *protocol) {
	for (SInt8 mask = 0; mask < 4; mask++) {
		struct objc_method_description description = protocol_getMethodDescription(protocol, selector, (mask & 0x01), (mask & 0x02));
		if (description.name == NULL && description.types == NULL) continue;
		
		return [NSMethodSignature signatureWithObjCTypes:description.types];
	}
	
	NSMethodSignature *signature = nil;
	
	unsigned int count = 0;
	Protocol **conformingProtocols = protocol_copyProtocolList(protocol, &count);
	
	if (count != 0) {
		for (unsigned int currentIndex = 0; currentIndex < count; currentIndex++) {
			Protocol *currentProtocol = conformingProtocols[currentIndex];
			signature = AFProtcolGetMethodSignature(selector, currentProtocol);
			if (signature != nil) break;
		}
	}
	
	free(conformingProtocols);
	
	return signature;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return AFProtcolGetMethodSignature(selector, _protocol);
}

@end
