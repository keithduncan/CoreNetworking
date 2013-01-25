//
//  AFNetworkPipeStream.h
//  Go Server
//
//  Created by Keith Duncan on 17/12/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AFNetworkOutputStream : NSOutputStream

- (id)initWithFileDescriptor:(int)fileDescriptor;

@end

@interface AFNetworkInputStream : NSInputStream

- (id)initWithFileDescriptor:(int)fileDescriptor;

@end
