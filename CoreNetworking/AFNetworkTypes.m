//
//  AFNetworkTypes.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkTypes.h"

#import <sys/socket.h>
#import <arpa/inet.h>

// Note: for internetwork sockets, the address family is determined through resolution

const AFNetworkSocketSignature AFNetworkSocketSignatureInternetTCP = {
	.socketType = SOCK_STREAM,
	.protocol = IPPROTO_TCP,
};

const AFNetworkSocketSignature AFNetworkSocketSignatureInternetUDP = {
	.socketType = SOCK_DGRAM,
	.protocol = IPPROTO_UDP,
};
