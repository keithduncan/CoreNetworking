//
//  AFNetworkFunctions.h
//  Bonjour
//
//  Created by Keith Duncan on 02/01/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <sys/socket.h>

//
//	BSD Networking
//

extern bool af_sockaddr_compare(const struct sockaddr *addr_a, const struct sockaddr *addr_b);
extern const char *af_sockaddr_ntop(const struct sockaddr *addr, char *dst, size_t maxlen);

//
//	Cocoa Networking
//

extern NSError *AFNetworkErrorFromCFStreamError(CFStreamError error);

extern NSString *AFNetworkSocketAddressToPresentation(NSData *socketAddress);
