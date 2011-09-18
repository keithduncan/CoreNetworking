//
//  AFNetworkFunctions.m
//  Bonjour
//
//  Created by Keith Duncan on 02/01/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetworkFunctions.h"

#import <netdb.h>
#import <sys/socket.h>
#import <arpa/inet.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif
#import <Security/Security.h>

#import "AFNetworkStream.h"

#import "AFNetworkConstants.h"

NS_INLINE bool af_sockaddr_is_ipv4_mapped(const struct sockaddr *addr) {
	NSCParameterAssert(addr != NULL);
	
	const struct sockaddr_in6 *addr_6 = (const struct sockaddr_in6 *)addr;
	return ((addr->sa_family == AF_INET6) && IN6_IS_ADDR_V4MAPPED(&(addr_6->sin6_addr)));
}

bool af_sockaddr_compare(const struct sockaddr *addr_a, const struct sockaddr *addr_b) {
	/* we have to handle IPv6 IPV4MAPPED addresses - convert them to IPv4 */
	if (af_sockaddr_is_ipv4_mapped(addr_a)) {
		const struct sockaddr_in6 *addr_a6 = (const struct sockaddr_in6 *)addr_a;
		
		struct sockaddr_in *addr_a4 = (struct sockaddr_in *)alloca(sizeof(struct sockaddr_in));
		memset(addr_a4, 0, sizeof(struct sockaddr_in));
		
		memcpy(&(addr_a4->sin_addr.s_addr), &(addr_a6->sin6_addr.s6_addr[12]), sizeof(struct in_addr));
		addr_a4->sin_port = addr_a6->sin6_port;
		addr_a = (const struct sockaddr *)addr_a4;
	}
	if (af_sockaddr_is_ipv4_mapped(addr_b)) {
		const struct sockaddr_in6 *addr_b6 = (const struct sockaddr_in6 *)addr_b;
		
		struct sockaddr_in *addr_b4 = (struct sockaddr_in *)alloca(sizeof(struct sockaddr_in));
		memset(addr_b4, 0, sizeof(struct sockaddr_in));
		
		memcpy(&(addr_b4->sin_addr.s_addr), &(addr_b6->sin6_addr.s6_addr[12]), sizeof(struct in_addr));
		addr_b4->sin_port = addr_b6->sin6_port;
		addr_b = (const struct sockaddr *)addr_b4;
	}
	
	if (addr_a->sa_family != addr_b->sa_family) {
		return false;
	}
	
	if (addr_a->sa_family == AF_INET) {
		const struct sockaddr_in *a_in = (struct sockaddr_in *)addr_a;
		const struct sockaddr_in *b_in = (struct sockaddr_in *)addr_b;
		
		// Compare addresses
		if ((a_in->sin_addr.s_addr != INADDR_ANY) && (b_in->sin_addr.s_addr != INADDR_ANY) && (a_in->sin_addr.s_addr != b_in->sin_addr.s_addr)) {
			return false;
		}
		
		// Compare ports
		if ((a_in->sin_port == 0) || (b_in->sin_port == 0) || (a_in->sin_port == b_in->sin_port)) {
			return true;
		}
	}
	
	if (addr_a->sa_family == AF_INET6) {
		const struct sockaddr_in6 *addr_a6 = (const struct sockaddr_in6 *)addr_a;
		const struct sockaddr_in6 *addr_b6 = (const struct sockaddr_in6 *)addr_b;
		
		/* compare scope */
		if (addr_a6->sin6_scope_id && addr_b6->sin6_scope_id && (addr_a6->sin6_scope_id != addr_b6->sin6_scope_id)) {
			return false;
		}
		
		/* compare address part 
		 * either may be IN6ADDR_ANY, resulting in a good match */
		if ((memcmp(&(addr_a6->sin6_addr), &in6addr_any, sizeof(struct in6_addr)) != 0) &&
			(memcmp(&(addr_b6->sin6_addr), &in6addr_any, sizeof(struct in6_addr)) != 0) &&
			(memcmp(&(addr_a6->sin6_addr), &(addr_b6->sin6_addr), sizeof(struct in6_addr)) != 0)) {
			return false;
		}
		
		/* compare port part 
		 * either port may be 0 (any), resulting in a good match */
		return ((addr_a6->sin6_port == 0) || (addr_b6->sin6_port == 0) || (addr_a6->sin6_port == addr_b6->sin6_port));
	}
	
	[NSException raise:NSInvalidArgumentException format:@"%s, unknown address family (%ld)", __PRETTY_FUNCTION__, (unsigned long)addr_a->sa_family];
	return false;
}

const char *af_sockaddr_ntop(const struct sockaddr *addr, char *dst, size_t maxlen) {
	switch (addr->sa_family) {
		case AF_INET:;
			return inet_ntop(AF_INET, &(((struct sockaddr_in *)addr)->sin_addr), dst, maxlen); 
		case AF_INET6:;
			return inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)addr)->sin6_addr), dst, maxlen); 
	}
	
	return NULL;
}

NSString *AFNetworkSocketAddressToPresentation(NSData *socketAddress) {
	CFRetain(socketAddress);
	
	char socketAddressPresentation[INET6_ADDRSTRLEN] = {0};
	size_t socketAddressPresentationLength = (sizeof(socketAddressPresentation) / sizeof(*socketAddressPresentation));
	
	BOOL socketAddressPresentationConverted = (af_sockaddr_ntop((const struct sockaddr *)[socketAddress bytes], socketAddressPresentation, socketAddressPresentationLength) != NULL);
	
	CFRelease(socketAddress);
	
	if (!socketAddressPresentationConverted) {
		return nil;
	}
	
	return [[[NSString alloc] initWithBytes:socketAddressPresentation length:socketAddressPresentationLength encoding:NSASCIIStringEncoding] autorelease];
}

NSError *AFNetworkStreamPrepareError(AFNetworkStream *stream, NSError *error) {
#define AFNetworkStreamNotConnectedToInternetErrorDescription() NSLocalizedStringFromTableInBundle(@"You\u2019re not connected to the Internet", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError not connected to internet error description")
	
	if (![stream isOpen]) {
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   AFNetworkStreamNotConnectedToInternetErrorDescription(), NSLocalizedDescriptionKey,
								   NSLocalizedStringFromTableInBundle(@"This computer\u2019s Internet connection appears to be offline.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError offline error recovery suggestion"), NSLocalizedRecoverySuggestionErrorKey,
								   error, NSUnderlyingErrorKey,
								   nil];
		error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkErrorNotConnectedToInternet userInfo:errorInfo];
	}
	
	if ([[error domain] isEqualToString:NSPOSIXErrorDomain]) {
		switch ([error code]) {
			case ENOTCONN:;
				NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										   AFNetworkStreamNotConnectedToInternetErrorDescription(), NSLocalizedDescriptionKey,
										   NSLocalizedStringFromTableInBundle(@"This computer\u2019s Internet connection appears to have gone offline.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError went offline error recovery suggestion"), NSLocalizedRecoverySuggestionErrorKey,
										   error, NSUnderlyingErrorKey,
										   nil];
				error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkErrorNetworkConnectionLost userInfo:errorInfo];
				break;
		}
	}
	
#define AFNetworkErrorCodeInRange(code, a, b) (code >= MIN(a, b) && code <= MAX(a, b) ? YES : NO)
	
	if ([[error domain] isEqualToString:NSOSStatusErrorDomain]) {
		if (AFNetworkErrorCodeInRange([error code], errSSLProtocol, errSSLLast)) {
			NSString *hostname = [stream streamPropertyForKey:(id)kCFStreamPropertySocketRemoteHostName];
			
			NSString *errorDescription = NSLocalizedStringFromTableInBundle(@"An SSL error has occurred and a secure connection to the server cannot be made.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError SSL default error description");
			AFNetworkErrorCode errorCode = AFNetworkSecureErrorConnectionFailed;
			
			switch ([error code]) {
				case errSSLCertExpired:;
					if (hostname == nil) {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server has expired.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError SSL certificate expired error description");
					} else {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server has expired. You might be connecting to a server that is pretending to be \u201c%@\u201d which could put your confidential information at risk.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError SSL certificate expired with hostname error description");
					}
					errorCode = AFNetworkSecureErrorServerCertificateExpired;
					break;
				case errSSLCertNotYetValid:;
					if (hostname == nil) {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server is not yet valid.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError SSL certificate not yet valid error description");
					} else {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server is not yet valid. You might be connecting to a server that is pretending to be \u201c%@\u201d which could put your confidential information at risk.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError SSL certificate not yet valid with hostname error description");
					}
					errorCode = AFNetworkSecureErrorServerCertificateNotYetValid;
					break;
				case errSSLHostNameMismatch:;
					if (hostname == nil) {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server is invalid.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError SSL certificate invalid error description");
					} else {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server is invalid. You might be connecting to a server that is pretending to be \u201c%@\u201d which could put your confidential information at risk.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError SSL certificate invalid with hostname error description");
					}
					errorCode = AFNetworkSecureErrorServerCertificateUntrusted;
					break;
				case errSSLPeerUnknownCA:;
					if (hostname == nil) {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server was signed by an unknown certifying authority.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError SSL certificate unknown CA error description");
					} else {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server was signed by an unknown certifying authority. You might be connecting to a server that is pretending to be \u201c%@\u201d which could put your confidential information at risk.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareError SSL certificate unknown CA with hostname error description");
					}
					errorCode = AFNetworkSecureErrorServerCertificateHasUnknownRoot;
					break;
			}
			
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									   errorDescription, NSLocalizedDescriptionKey,
									   nil];
			error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:errorCode userInfo:errorInfo];
		}
	}
	
#undef AFNetworkErrorCodeInRange
	
	return error;
}
