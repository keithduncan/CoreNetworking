//
//  AFNetworkPacket+AFNetworkPrivate.h
//  CoreNetworking
//
//  Created by Keith Duncan on 07/02/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AFNetworkPacket.h"

@interface AFNetworkPacket ()
@property (assign, nonatomic) NSInteger idleTimeoutDisableCount;
@property (retain, nonatomic) NSTimer *idleTimeoutTimer;
@end

@interface AFNetworkPacket (AFNetworkPrivate)

- (void)_resetIdleTimeoutTimer;
- (void)_stopIdleTimeoutTimer;

@end
