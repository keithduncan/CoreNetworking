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

const AFNetworkSocketSignature AFNetworkSocketSignatureTCP = {
	.socketType = SOCK_STREAM,
	.protocol = IPPROTO_TCP
};

const AFNetworkSocketSignature AFNetworkSocketSignatureUDP = {
	.socketType = SOCK_DGRAM,
	.protocol = IPPROTO_UDP
};

const AFNetworkTransportSignature AFNetworkTransportSignatureHTTP = {
	.type = &AFNetworkSocketSignatureTCP,
	.port = 80,
};

const AFNetworkTransportSignature AFNetworkTransportSignatureHTTPS = {
	.type = &AFNetworkSocketSignatureTCP,
	.port = 443,
};
