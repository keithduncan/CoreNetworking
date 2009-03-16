//
//  AFNetworkFunctions.m
//  Bonjour
//
//  Created by Keith Duncan on 02/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "AFNetworkFunctions.h"

#import <sys/socket.h>
#import <arpa/inet.h>

bool sockaddr_compare(const struct sockaddr *addr_a, const struct sockaddr *addr_b) {
	if (addr_a->sa_family != addr_b->sa_family) return false;
	
	if (addr_a->sa_family == AF_INET) {
		const struct sockaddr_in *a_in = (struct sockaddr_in *)addr_a;
		const struct sockaddr_in *b_in = (struct sockaddr_in *)addr_b;
		
		// Compare addresses
		if ((a_in->sin_addr.s_addr != INADDR_ANY) &&
			(b_in->sin_addr.s_addr != INADDR_ANY) &&
			(a_in->sin_addr.s_addr != b_in->sin_addr.s_addr))
		{
			return false;
		}
		
		// Compare ports
		if ((a_in->sin_port == 0) || (b_in->sin_port == 0) ||
			(a_in->sin_port == b_in->sin_port))
		{
			return true;
		}
	} else if (addr_a->sa_family == AF_INET6) {
		const struct sockaddr_in6 *a_in6 = (struct sockaddr_in6 *)addr_a;
		const struct sockaddr_in6 *b_in6 = (struct sockaddr_in6 *)addr_b;
		
		assert(0); // Note: IPv6 comparison not yet implemented
	} else {
		assert(0); // Note: Unknown address family
	}
	
	return false;
}

const char *sockaddr_ntop(const struct sockaddr *addr, char *dst, size_t maxlen) {
    switch (addr->sa_family) {
        case AF_INET: 
            return inet_ntop(AF_INET, &(((struct sockaddr_in *)addr)->sin_addr), dst, maxlen); 
        case AF_INET6: 
			return inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)addr)->sin6_addr), dst, maxlen); 
        default: 
            return strncpy(dst, "Unknown AF", maxlen);
    } 
	
    return NULL;
}
