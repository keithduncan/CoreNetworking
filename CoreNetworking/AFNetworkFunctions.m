//
//  AFNetworkFunctions.m
//  Bonjour
//
//  Created by Keith Duncan on 02/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import "AFNetworkFunctions.h"

#import <netdb.h>
#import <sys/socket.h>
#import <arpa/inet.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

NS_INLINE bool sockaddr_is_ipv4_mapped(const struct sockaddr *addr) {
	NSCParameterAssert(addr != NULL);
	
	const struct sockaddr_in6 *addr_6 = (const struct sockaddr_in6 *)addr;
	return ((addr->sa_family == AF_INET6) && IN6_IS_ADDR_V4MAPPED(&(addr_6->sin6_addr)));
}

bool sockaddr_compare(const struct sockaddr *addr_a, const struct sockaddr *addr_b) {	
	/* we have to handle IPv6 IPV4MAPPED addresses - convert them to IPv4 */
	if (sockaddr_is_ipv4_mapped(addr_a)) {
		const struct sockaddr_in6 *addr_a6 = (const struct sockaddr_in6 *)addr_a;
		
		struct sockaddr_in *addr_a4 = (struct sockaddr_in *)alloca(sizeof(struct sockaddr_in));
		memset(addr_a4, 0, sizeof(struct sockaddr_in));
		
		memcpy(&(addr_a4->sin_addr.s_addr), &(addr_a6->sin6_addr.s6_addr[12]), sizeof(struct in_addr));
		addr_a4->sin_port = addr_a6->sin6_port;
		addr_a = (const struct sockaddr *)addr_a4;
	}
	
	if (sockaddr_is_ipv4_mapped(addr_b)) {
		const struct sockaddr_in6 *addr_b6 = (const struct sockaddr_in6 *)addr_b;
		
		struct sockaddr_in *addr_b4 = (struct sockaddr_in *)alloca(sizeof(struct sockaddr_in));
		memset(addr_b4, 0, sizeof(struct sockaddr_in));
		
		memcpy(&(addr_b4->sin_addr.s_addr), &(addr_b6->sin6_addr.s6_addr[12]), sizeof(struct in_addr));
		addr_b4->sin_port = addr_b6->sin6_port;
		addr_b = (const struct sockaddr *)addr_b4;
	}
	
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
	} if (addr_a->sa_family == AF_INET6) {
		const struct sockaddr_in6 *addr_a6 = (const struct sockaddr_in6 *)addr_a;
		const struct sockaddr_in6 *addr_b6 = (const struct sockaddr_in6 *)addr_b;
		
		/* compare scope */
		if (addr_a6->sin6_scope_id && addr_b6->sin6_scope_id && (addr_a6->sin6_scope_id != addr_b6->sin6_scope_id)) return false;
		
		/* compare address part 
		 * either may be IN6ADDR_ANY, resulting in a good match */
		if ((memcmp(&(addr_a6->sin6_addr), &in6addr_any,
		            sizeof(struct in6_addr)) != 0) &&
		    (memcmp(&(addr_b6->sin6_addr), &in6addr_any,
					sizeof(struct in6_addr)) != 0) &&
		    (memcmp(&(addr_a6->sin6_addr), &(addr_b6->sin6_addr),
					sizeof(struct in6_addr)) != 0))
		{
			return false;
		}
		
		/* compare port part 
		 * either port may be 0 (any), resulting in a good match */
		return ((addr_a6->sin6_port == 0) || (addr_b6->sin6_port == 0) || (addr_a6->sin6_port == addr_b6->sin6_port));
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

NSError *AFErrorFromCFStreamError(CFStreamError error) {
	if (error.domain == 0 && error.error == 0) return nil;
	NSString *domain = @"Unlisted CFStreamError Domain", *message = nil;
	
	if (error.domain == kCFStreamErrorDomainPOSIX) {
		domain = NSPOSIXErrorDomain;
	} else if (error.domain == kCFStreamErrorDomainMacOSStatus) {
		domain = NSOSStatusErrorDomain;
	} else if (error.domain == kCFStreamErrorDomainMach) {
		domain = NSMachErrorDomain;
	} else if (error.domain == kCFStreamErrorDomainNetDB) {
		domain = @"kCFStreamErrorDomainNetDB";
		message = [NSString stringWithCString:gai_strerror(error.error) encoding:NSASCIIStringEncoding];
	} else if (error.domain == kCFStreamErrorDomainNetServices) {
		domain = @"kCFStreamErrorDomainNetServices";
	} else if (error.domain == kCFStreamErrorDomainSOCKS) {
		domain = @"kCFStreamErrorDomainSOCKS";
	} else if (error.domain == kCFStreamErrorDomainSystemConfiguration) {
		domain = @"kCFStreamErrorDomainSystemConfiguration";
	} else if (error.domain == kCFStreamErrorDomainSSL) {
		domain = @"kCFStreamErrorDomainSSL";
	}
	
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  message, NSLocalizedDescriptionKey,
							  nil];
	
	return [NSError errorWithDomain:domain code:error.error userInfo:userInfo];
}
