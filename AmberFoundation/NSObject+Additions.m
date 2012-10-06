//
//  NSObject+Additions.m
//  Amber
//
//  Created by Keith Duncan on 13/10/2007.
//  Copyright 2007. All rights reserved.
//

#import "NSObject+Additions.h"

#import "AFProtocolProxy.h"

@implementation NSObject (AFAdditions)

- (id)protocolProxy:(Protocol *)protocol {
	return [[[AFProtocolProxy alloc] initWithTarget:self protocol:protocol] autorelease];
}

@end
