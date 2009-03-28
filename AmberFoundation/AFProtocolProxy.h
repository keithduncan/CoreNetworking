//
//  AFProtocolProxy.h
//  Priority
//
//  Created by Keith Duncan on 22/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AFProtocolProxy : NSProxy {
	id _target;
	Protocol *_protocol;
}

- (id)initWithTarget:(id)target protocol:(Protocol *)protocol;

@end
