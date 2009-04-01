//
//  AFNetworkFunctions.h
//  Bonjour
//
//  Created by Keith Duncan on 02/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

//
// These functions operate on data in the Transport and Internet layers, as defined in RFC 1122
//

#import <Foundation/Foundation.h>

#import <sys/socket.h>

bool sockaddr_compare(const struct sockaddr *addr_a, const struct sockaddr *addr_b);
const char *sockaddr_ntop(const struct sockaddr *addr, char *dst, size_t maxlen);
