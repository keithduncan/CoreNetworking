//
//  AFNetworkTypes.m
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "AFNetworkTypes.h"

#import <sys/socket.h>
#import <arpa/inet.h>

// Note: for internetwork sockets, the address family is determined through resolution

const AFSocketSignature AFSocketSignatureNetworkTCP = {
	.socketType = SOCK_STREAM,
	.protocol = IPPROTO_TCP,
};

const AFSocketSignature AFSocketSignatureNetworkUDP = {
	.socketType = SOCK_DGRAM,
	.protocol = IPPROTO_UDP,
};

const AFSocketSignature AFSocketSignatureLocalPath = {
	.socketType = SOCK_STREAM,
	.protocol = 0,
};
