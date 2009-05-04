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

const AFSocketTransportType AFSocketTransportTypeTCP = {
	.socketType = SOCK_STREAM,
	.protocol = IPPROTO_TCP
};

const AFSocketTransportType AFSocketTransportTypeUDP = {
	.socketType = SOCK_DGRAM,
	.protocol = IPPROTO_UDP
};

const AFSocketTransportSignature AFSocketTransportSignatureHTTP = {
	.type = &AFSocketTransportTypeTCP,
	.port = 80,
};

const AFSocketTransportSignature AFSocketTransportSignatureHTTPS = {
	.type = &AFSocketTransportTypeTCP,
	.port = 443,
};
