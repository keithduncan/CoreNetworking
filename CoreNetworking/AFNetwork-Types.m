//
//  AFNetworkTypes.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetwork-Types.h"

#import <sys/socket.h>
#import <arpa/inet.h>

// Note: for internetwork sockets, the address family is determined through resolution

AFNetworkSocketSignature const AFNetworkSocketSignatureInternetTCP = {
	.socketType = SOCK_STREAM,
	.protocol = IPPROTO_TCP,
};

AFNetworkSocketSignature const AFNetworkSocketSignatureInternetUDP = {
	.socketType = SOCK_DGRAM,
	.protocol = IPPROTO_UDP,
};
