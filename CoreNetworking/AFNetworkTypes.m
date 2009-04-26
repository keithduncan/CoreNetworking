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

const AFSocketType AFSocketTypeTCP = {
	.socketType = SOCK_STREAM,
	.protocol = IPPROTO_TCP
};

const AFSocketType AFSocketTypeUDP = {
	.socketType = SOCK_DGRAM,
	.protocol = IPPROTO_UDP
};

const AFSocketTransport AFSocketTransportHTTP = {
	.type = &AFSocketTypeTCP,
	.port = 80,
};

const AFSocketTransport AFSocketTransportHTTPS = {
	.type = &AFSocketTypeTCP,
	.port = 443,
};
