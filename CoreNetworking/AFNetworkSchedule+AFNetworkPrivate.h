//
//  AFNetworkSchedule_AFNetworkPrivate.h
//  CoreNetworking
//
//  Created by Keith Duncan on 26/01/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import <CoreNetworking/CoreNetworking.h>

@interface AFNetworkSchedule (AFNetworkPrivate)

- (void)_performBlock:(void (^)(void))block;

@end
