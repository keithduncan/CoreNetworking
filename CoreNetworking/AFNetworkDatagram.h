//
//  AFNetworkDatagram.h
//  CoreNetworking
//
//  Created by Keith Duncan on 26/05/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AFNetworkDatagram : NSObject

- (id)initWithSenderAddress:(NSData *)senderAddress data:(NSData *)data metadata:(NSSet *)metadata;

@property (readonly, copy, nonatomic) NSData *senderAddress;
@property (readonly, copy, nonatomic) NSData *data;
@property (readonly, copy, nonatomic) NSSet *metadata;

@end
