//
//  AFNetworkSocketOption.h
//  CoreNetworking
//
//  Created by Keith Duncan on 27/05/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AFNetworkSocketOption : NSObject

+ (instancetype)optionWithLevel:(int)level option:(int)option value:(NSValue *)value;

+ (instancetype)optionWithLevel:(int)level option:(int)option data:(NSData *)data;

- (id)initWithLevel:(int)level option:(int)option data:(NSData *)data;

@property (readonly, assign, nonatomic) int level;
@property (readonly, assign, nonatomic) int option;

@property (readonly, copy, nonatomic) NSData *data;

@end
