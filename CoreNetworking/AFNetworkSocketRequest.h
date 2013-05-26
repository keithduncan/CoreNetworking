//
//  AFNetworkSocketRequest.h
//  CoreNetworking
//
//  Created by Keith Duncan on 26/05/2013.
//  Copyright (c) 2013 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Types.h"

/*!
	\brief
	Socket Request is to the kernel, as an NSURLRequest is to it's [URL host]
 */
@interface AFNetworkSocketRequest : NSObject

- (id)initWithSocketSignature:(AFNetworkSocketSignature)socketSignature socketAddress:(NSData *)socketAddress;

@property (readonly, assign, nonatomic) AFNetworkSocketSignature socketSignature;
@property (readonly, copy, nonatomic) NSData *socketAddress;

@end
