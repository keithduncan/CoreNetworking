//
//  AFNetworkPacketClose.h
//  CoreNetworking
//
//  Created by Keith Duncan on 09/08/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetworkPacket.h"

/*!
	\brief
	Can be enqueued to close the stream when dequeued
 */
@interface AFNetworkPacketClose : AFNetworkPacket <AFNetworkPacketReading, AFNetworkPacketWriting>

@end
