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

#import "AmberNetworking.h"

#import <sys/socket.h>
#import <netinet/in.h>

bool sockaddr_compare(const struct sockaddr *a, const struct sockaddr *b);
