//
//  AFNetworkFunctions.m
//  Bonjour
//
//  Created by Keith Duncan on 02/01/2009.
//  Copyright 2009. All rights reserved.
//

#import "AFNetwork-Functions.h"

#import <netdb.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <arpa/inet.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#import <Security/SecureTransport.h>
#endif /* TARGET_OS_IPHONE */
#import <Security/Security.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import "AFNetworkStreamQueue.h"

#import "AFNetwork-Constants.h"

/* 
	Note
	
	explicit cast to sockaddr_in, this *will* work for both IPv4 and IPv6 as the port field is in the same location and the same width, however we should investigate alternatives that don't require this
 */
#define AFNETWORK_SOCKADDR_PORT(ptr) ((struct sockaddr_in *)ptr)->sin_port

uint16_t af_sockaddr_in_read_port(struct sockaddr_storage const *addr) {
	return ntohs(AFNETWORK_SOCKADDR_PORT(addr));
}

void af_sockaddr_in_write_port(struct sockaddr_storage *addr, uint16_t port) {
	AFNETWORK_SOCKADDR_PORT(addr) = htons(port);
}

#undef AFNETWORK_SOCKADDR_PORT

static inline bool af_sockaddr_is_ipv4_mapped(struct sockaddr_storage const *addr) {
	NSCParameterAssert(addr != NULL);
	
	struct sockaddr_in6 const *addr_6 = (struct sockaddr_in6 const *)addr;
	return ((addr->ss_family == AF_INET6) && IN6_IS_ADDR_V4MAPPED(&(addr_6->sin6_addr)));
}

bool af_sockaddr_compare(struct sockaddr_storage const *addr_a, struct sockaddr_storage const *addr_b) {
	// We have to handle IPv6 IPV4MAPPED addresses - convert them to IPv4
	if (af_sockaddr_is_ipv4_mapped(addr_a)) {
		struct sockaddr_in6 const *addr_a6 = (struct sockaddr_in6 const *)addr_a;
		
		struct sockaddr_in *addr_a4 = (struct sockaddr_in *)alloca(sizeof(struct sockaddr_in));
		memset(addr_a4, 0, sizeof(struct sockaddr_in));
		
		memcpy(&(addr_a4->sin_addr.s_addr), &(addr_a6->sin6_addr.s6_addr[12]), sizeof(struct in_addr));
		addr_a4->sin_port = addr_a6->sin6_port;
		addr_a = (struct sockaddr_storage const *)addr_a4;
	}
	if (af_sockaddr_is_ipv4_mapped(addr_b)) {
		struct sockaddr_in6 const *addr_b6 = (struct sockaddr_in6 const *)addr_b;
		
		struct sockaddr_in *addr_b4 = (struct sockaddr_in *)alloca(sizeof(struct sockaddr_in));
		memset(addr_b4, 0, sizeof(struct sockaddr_in));
		
		memcpy(&(addr_b4->sin_addr.s_addr), &(addr_b6->sin6_addr.s6_addr[12]), sizeof(struct in_addr));
		addr_b4->sin_port = addr_b6->sin6_port;
		addr_b = (struct sockaddr_storage const *)addr_b4;
	}
	
	if (addr_a->ss_family != addr_b->ss_family) {
		return false;
	}
	
	int32_t addr_a_family = addr_a->ss_family;
	
	if (addr_a_family == AF_INET) {
		struct sockaddr_in const *a_in = (struct sockaddr_in *)addr_a;
		struct sockaddr_in const *b_in = (struct sockaddr_in *)addr_b;
		
		// Compare addresses
		if ((a_in->sin_addr.s_addr != INADDR_ANY) && (b_in->sin_addr.s_addr != INADDR_ANY) && (a_in->sin_addr.s_addr != b_in->sin_addr.s_addr)) {
			return false;
		}
		
		// Compare ports
		if ((a_in->sin_port == 0) || (b_in->sin_port == 0) || (a_in->sin_port == b_in->sin_port)) {
			return true;
		}
	}
	
	if (addr_a_family == AF_INET6) {
		struct sockaddr_in6 const *addr_a6 = (struct sockaddr_in6 const *)addr_a;
		struct sockaddr_in6 const *addr_b6 = (struct sockaddr_in6 const *)addr_b;
		
		// Compare scope
		if (addr_a6->sin6_scope_id && addr_b6->sin6_scope_id && (addr_a6->sin6_scope_id != addr_b6->sin6_scope_id)) {
			return false;
		}
		
		// Compare address part either may be IN6ADDR_ANY, resulting in a good match
		if ((memcmp(&(addr_a6->sin6_addr), &in6addr_any, sizeof(struct in6_addr)) != 0) &&
			(memcmp(&(addr_b6->sin6_addr), &in6addr_any, sizeof(struct in6_addr)) != 0) &&
			(memcmp(&(addr_a6->sin6_addr), &(addr_b6->sin6_addr), sizeof(struct in6_addr)) != 0)) {
			return false;
		}
		
		// Compare port part either port may be 0 (any), resulting in a good match
		return ((addr_a6->sin6_port == 0) || (addr_b6->sin6_port == 0) || (addr_a6->sin6_port == addr_b6->sin6_port));
	}
	
	@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"%s, unknown address family (%ld)", __PRETTY_FUNCTION__, (unsigned long)addr_a_family] userInfo:nil];
	return false;
}

int af_sockaddr_ntop(struct sockaddr_storage const *addr, char *destination, socklen_t destinationSize) {
	return getnameinfo((struct sockaddr const *)addr, addr->ss_len, destination, destinationSize, NULL, 0, NI_NUMERICHOST);
}

int af_sockaddr_pton(char const *presentation, struct sockaddr_storage *storage) {
	struct addrinfo addressInfoHints = {
		.ai_flags = AI_NUMERICHOST,
	};
	struct addrinfo *addressInfoList = NULL;
	int getaddrinfoError = getaddrinfo(presentation, NULL, &addressInfoHints, &addressInfoList);
	if (getaddrinfoError != 0) {
		return getaddrinfoError;
	}
	
	memcpy(storage, addressInfoList[0].ai_addr, addressInfoList[0].ai_addrlen);
	freeaddrinfo(addressInfoList);
	
	return 0;
}

int af_bind(int fileDescriptor, struct sockaddr_storage const *address, socklen_t addressLength) {
	if (address->ss_family == AF_INET6) {
		/*
			Note
			
			we use getaddrinfo to be address family agnostic
			
			however when binding a socket to the wildcard IPv6 address "::" by default OS X also listens on the wildcard IPv4 address "0.0.0.0"
			
			a subsequent socket binding to the wildcard IPv4 address will fail with EADDRINUSE even though we didn't actually bind that address in userspace
			
			this prevents that behaviour, at the cost of hardcoding per-protocol knowledge into otherwise protocol agnostic code
		 */
		int ipv6Only = 1;
		__unused int ipv6OnlyError = setsockopt(fileDescriptor, IPPROTO_IPV6, IPV6_V6ONLY, &ipv6Only, sizeof(ipv6Only));
	}
	
	return bind(fileDescriptor, (struct sockaddr const*)address, addressLength);
}

#pragma mark -

static BOOL _AFNetworkSocketCheckGetAddressInfoError(int result, NSError **errorRef) {
	if (result == 0) {
		return YES;
	}
	
	if (errorRef != NULL) {
		const char *underlyingErrorDescription = gai_strerror(result);
		
		NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								   [NSString stringWithUTF8String:underlyingErrorDescription], NSLocalizedDescriptionKey,
								   nil];
		*errorRef = [NSError errorWithDomain:[AFCoreNetworkingBundleIdentifier stringByAppendingString:@".getaddrinfo"] code:result userInfo:errorInfo];
	}
	return NO;
}

static NSString *_AFNetworkSocketAddressDataIsNotValidError(NSError **errorRef) {
	if (errorRef != NULL) {
		NSDictionary *errorInfo = @{
			NSLocalizedDescriptionKey : NSLocalizedString(@"Socket address data is not valid", @"AFNetwork-Functions invalid sockaddr_storage data"),
		};
		*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkErrorUnknown userInfo:errorInfo];
	}
	return nil;
}

NSString *AFNetworkSocketAddressToPresentation(NSData *socketAddress, NSError **errorRef) {
	if ([socketAddress length] < sizeof(((struct sockaddr_storage const *)NULL)->ss_len)) {
		return _AFNetworkSocketAddressDataIsNotValidError(errorRef);
	}
	
	CFRetain(socketAddress);
	
	struct sockaddr_storage const *socketAddressBytes = (struct sockaddr_storage const *)[socketAddress bytes];
	
	__uint8_t length = socketAddressBytes->ss_len;
	if ([socketAddress length] != length) {
		CFRelease(socketAddress);
		
		return _AFNetworkSocketAddressDataIsNotValidError(errorRef);
	}
	
	char socketAddressPresentation[INET6_ADDRSTRLEN] = {};
	socklen_t socketAddressPresentationLength = (sizeof(socketAddressPresentation) / sizeof(*socketAddressPresentation));
	
	int ntopError = af_sockaddr_ntop(socketAddressBytes, socketAddressPresentation, socketAddressPresentationLength);
	
	CFRelease(socketAddress);
	
	if (!_AFNetworkSocketCheckGetAddressInfoError(ntopError, errorRef)) {
		return nil;
	}
	
	return [[[NSString alloc] initWithCString:socketAddressPresentation encoding:NSASCIIStringEncoding] autorelease];
}

NSData *AFNetworkSocketPresentationToAddress(NSString *presentation, NSError **errorRef) {
	char const *presentationBytes = [presentation UTF8String];
	
	struct sockaddr_storage storage = {};
	int ptonError = af_sockaddr_pton(presentationBytes, &storage);
	
	if (!_AFNetworkSocketCheckGetAddressInfoError(ptonError, errorRef)) {
		return nil;
	}
	
	return [NSData dataWithBytes:&storage length:storage.ss_len];
}

BOOL AFNetworkIsConnectedToInternet(void) {
	/*
		Note
		
		This may seem like a massively hypocritical implementation for two reasons
		- using synchronous API
		- using synchronous reachability
		- using reachability with a non-parameterised hostname
		But wait, there's more!
		
		Burried in CFNetwork is a function `BOOL _CFNetworkIsConnectedToInternet(void)`, the implementation that follows is based on the disassembly of that function
		(Unfortunately, this function isn't included in the <http://opensource.apple.com> code dump, you'll have to disassemble it yourself if you're curious)
		Note critically, this function _doesn't_ use the hostname the client is attempting to connect to, it uses a static value of `apple.com`, we also apply that here
		
		I believe the problem is that DNS is typically transported using UDP
		In the absence of a failed TCP handshake sequence to indicate a connection error, we apply the following logic:
		
		1. Determine the system's reachability status
		2. If the network isn't reachable
			assume there was no entry in the local cache and we _couldn't ask_ any remote servers
		3. If the network is 'reachable'
			assume there was no entry in the local cache and there was _no reply_ from any remote server
	 */
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "apple.com");
	
	SCNetworkReachabilityFlags reachabilityFlags = 0;
	Boolean getReachabilityFlags = SCNetworkReachabilityGetFlags(reachability, &reachabilityFlags);
	
	CFRelease(reachability);
	
	if (!getReachabilityFlags) {
		return NO;
	}
	
	SCNetworkReachabilityFlags requiredReachabilityValue = kSCNetworkReachabilityFlagsReachable;
	SCNetworkReachabilityFlags requiredReachabilityMask = (kSCNetworkReachabilityFlagsReachable | kSCNetworkReachabilityFlagsConnectionRequired);
	
	if ((reachabilityFlags & requiredReachabilityMask) != requiredReachabilityValue) {
		return NO;
	}
	
	return YES;
}

#define AFNetworkStreamNotConnectedToInternetErrorDescription() NSLocalizedStringFromTableInBundle(@"You aren\u2019t connected to the Internet", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError not connected to internet error description")
#define AFNetworkStreamCouldntConnectToServerErrorDescription() NSLocalizedStringFromTableInBundle(@"Couldn\u2019t connect to the server", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError couldn't connect to server error description")

static BOOL _AFNetworkCheckIsConnectedToInternet(NSError *underlyingError, NSError **errorRef) {
	if (!AFNetworkIsConnectedToInternet()) {
		if (errorRef != NULL) {
			NSMutableDictionary *errorInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											  AFNetworkStreamNotConnectedToInternetErrorDescription(), NSLocalizedDescriptionKey,
											  NSLocalizedStringFromTableInBundle(@"This device\u2019s Internet connection appears to be offline.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError not connected to internet error recovery suggestion"), NSLocalizedRecoverySuggestionErrorKey,
											  nil];
			[errorInfo setValue:underlyingError forKey:NSUnderlyingErrorKey];
			
			*errorRef = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkErrorNotConnectedToInternet userInfo:errorInfo];
		}
		return NO;
	}
	return YES;
}

NSError *AFNetworkStreamPrepareDisplayError(AFNetworkStreamQueue *stream, NSError *error) {
	NSString *streamRemoteHostname = [stream streamPropertyForKey:(id)kCFStreamPropertySocketRemoteHostName];
	
	if ([[error domain] isEqualToString:(id)kCFErrorDomainCFNetwork] && [error code] == kCFHostErrorUnknown) {
		int getaddrinfoError = [[[error userInfo] objectForKey:(id)kCFGetAddrInfoFailureKey] intValue];
		
		NSError *underlyingError = nil;
		BOOL checkGetaddrinfoError = _AFNetworkSocketCheckGetAddressInfoError(getaddrinfoError, &underlyingError);
		NSCParameterAssert(!checkGetaddrinfoError);
		
		switch (getaddrinfoError) {
#if 0
			case EAI_SYSTEM: /* system error returned in errno */
			{
				break;
			}
#endif /* 0 */
			
			case EAI_NONAME: /* hostname nor servname provided, or not known */
			{
				NSError *networkReachableError = nil;
				BOOL networkReachable = _AFNetworkCheckIsConnectedToInternet(error, &networkReachableError);
				if (!networkReachable) {
					return networkReachableError;
				}
				
				// fall though
			}
			
			case EAI_ADDRFAMILY: /* address family for hostname not supported */
			case EAI_AGAIN: /* temporary failure in name resolution */
			case EAI_BADFLAGS: /* invalid value for ai_flags */
			case EAI_FAIL: /* non-recoverable failure in name resolution */
			case EAI_FAMILY: /* ai_family not supported */
			case EAI_MEMORY: /*memory allocation failure */
			case EAI_NODATA: /* no address associated with hostname */
			case EAI_SERVICE: /* servname not supported for ai_socktype */
			case EAI_SOCKTYPE: /* ai_socktype not supported */
			case EAI_BADHINTS: /* invalid value for hints */
			case EAI_PROTOCOL: /* resolved protocol is unknown */
			case EAI_OVERFLOW: /* argument buffer overflow */
			default:
			{
				NSString *errorRecoverySuggestion = nil;
				if (streamRemoteHostname == nil) {
					errorRecoverySuggestion = NSLocalizedStringFromTableInBundle(@"The server couldn\u2019t be found, please check that your server address is correct.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError netdb error invalid hostname error description");
				}
				else {
					errorRecoverySuggestion = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The server \u201c%@\u201d couldn\u2019t be found, please check that your server address is correct.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError netdb error invalid hostname with hostname error description"), streamRemoteHostname];
				}
				
				NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										   AFNetworkStreamCouldntConnectToServerErrorDescription(), NSLocalizedDescriptionKey,
										   errorRecoverySuggestion,  NSLocalizedRecoverySuggestionErrorKey,
										   underlyingError, NSUnderlyingErrorKey,
										   nil];
				return [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkHostErrorInvalid userInfo:errorInfo];
			}
		}
	}
	
	if ([[error domain] isEqualToString:NSPOSIXErrorDomain]) {
		NSError *underlyingError = error;
		
		switch ([underlyingError code]) {
			case ENETDOWN: /* Network is down */
			case ENETUNREACH: /* Network is unreachable */
			case EHOSTUNREACH: /* No route to host */
			{
				NSError *networkReachableError = nil;
				BOOL networkReachable = _AFNetworkCheckIsConnectedToInternet(underlyingError, &networkReachableError);
				if (!networkReachable) {
					return networkReachableError;
				}
				
				break;
			}
			case ENETRESET: /* Network dropped connection on reset */
			{
				break;
			}
			case ECONNABORTED: /* Software caused connection abort */
			{
				break;
			}
			case ECONNRESET: /* Connection reset by peer */
			{
				NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										   NSLocalizedStringFromTableInBundle(@"Server unexpectedly dropped the connection", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError server unexpectedly disconnected error description"), NSLocalizedDescriptionKey,
										   NSLocalizedStringFromTableInBundle(@"This sometimes occurs when the server is busy. Please wait a few minutes and try again.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError server unexpectedly disconnected error recovery suggestion"), NSLocalizedRecoverySuggestionErrorKey,
										   underlyingError, NSUnderlyingErrorKey,
										   nil];
				return [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkStreamErrorServerClosed userInfo:errorInfo];
			}
			case ENOTCONN: /* Socket is not connected */
			{
				NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										   AFNetworkStreamNotConnectedToInternetErrorDescription(), NSLocalizedDescriptionKey,
										   NSLocalizedStringFromTableInBundle(@"This device\u2019s Internet connection appears to have gone offline.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError went offline error recovery suggestion"), NSLocalizedRecoverySuggestionErrorKey,
										   underlyingError, NSUnderlyingErrorKey,
										   nil];
				return [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkErrorNetworkConnectionLost userInfo:errorInfo];
			}
			case ESHUTDOWN: /* Can't send after socket shutdown */
			{
				break;
			}
			case ETIMEDOUT: /* Operation timed out */
			{
				/*
					Note
					
					this is received when our TCP keepalive probes go unanswered
				 */
				
				NSString *errorRecoverySuggestion = nil;
				if (streamRemoteHostname != nil) {
					errorRecoverySuggestion = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The server \u201c%@\u201d isn\u2019t responding.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError connection timed out with hostname error recovery suggestion"), streamRemoteHostname];
				}
				else {
					errorRecoverySuggestion = NSLocalizedStringFromTableInBundle(@"The server isn\u2019t responding.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError connection timed out error recovery suggestion");
				}
				
				NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										   AFNetworkStreamCouldntConnectToServerErrorDescription(), NSLocalizedDescriptionKey,
										   errorRecoverySuggestion, NSLocalizedRecoverySuggestionErrorKey,
										   underlyingError, NSUnderlyingErrorKey,
										   nil];
				return [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkHostErrorTimeout userInfo:errorInfo];
			}
			case EHOSTDOWN: /* Host is down */
			case ECONNREFUSED: /* Connection refused */
			{
				NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										   AFNetworkStreamCouldntConnectToServerErrorDescription(), NSLocalizedDescriptionKey,
										   underlyingError, NSUnderlyingErrorKey,
										   nil];
				return [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkHostErrorCannotConnect userInfo:errorInfo];
			}
			default:
			{
				
			}
		}
	}
	
#define AFNetworkErrorCodeInRange(code, a, b) (code >= MIN(a, b) && code <= MAX(a, b) ? YES : NO)
	
	if ([[error domain] isEqualToString:NSOSStatusErrorDomain]) {
		NSError *underlyingError = error;
		
		if (AFNetworkErrorCodeInRange([underlyingError code], errSSLProtocol, errSSLLast)) {
			NSString *errorDescription = NSLocalizedStringFromTableInBundle(@"An SSL error has occurred and a secure connection to the server cannot be made.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError SSL default error description");
			AFNetworkErrorCode errorCode = AFNetworkSecureErrorConnectionFailed;
			
			switch ([underlyingError code]) {
				case errSSLCertExpired:
				{
					if (streamRemoteHostname == nil) {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server has expired.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError SSL certificate expired error description");
					}
					else {
						errorDescription = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The certificate for this server has expired. You might be connecting to a server that is pretending to be \u201c%@\u201d which could put your confidential information at risk.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError SSL certificate expired with hostname error description"), streamRemoteHostname];
					}
					errorCode = AFNetworkSecureErrorServerCertificateExpired;
					break;
				}
				case errSSLCertNotYetValid:
				{
					if (streamRemoteHostname == nil) {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server is not yet valid.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError SSL certificate not yet valid error description");
					}
					else {
						errorDescription = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The certificate for this server is not yet valid. You might be connecting to a server that is pretending to be \u201c%@\u201d which could put your confidential information at risk.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError SSL certificate not yet valid with hostname error description"), streamRemoteHostname];
					}
					errorCode = AFNetworkSecureErrorServerCertificateNotYetValid;
					break;
				}
				case errSSLHostNameMismatch:
				{
					if (streamRemoteHostname == nil) {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server is invalid.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError SSL certificate invalid error description");
					}
					else {
						errorDescription = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The certificate for this server is invalid. You might be connecting to a server that is pretending to be \u201c%@\u201d which could put your confidential information at risk.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError SSL certificate invalid with hostname error description"), streamRemoteHostname];
					}
					errorCode = AFNetworkSecureErrorServerCertificateUntrusted;
					break;
				}
				case errSSLPeerUnknownCA:
				{
					if (streamRemoteHostname == nil) {
						errorDescription = NSLocalizedStringFromTableInBundle(@"The certificate for this server was signed by an unknown certifying authority.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError SSL certificate unknown CA error description");
					}
					else {
						errorDescription = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"The certificate for this server was signed by an unknown certifying authority. You might be connecting to a server that is pretending to be \u201c%@\u201d which could put your confidential information at risk.", nil, [NSBundle bundleWithIdentifier:AFCoreNetworkingBundleIdentifier], @"AFNetworkStreamPrepareDisplayError SSL certificate unknown CA with hostname error description"), streamRemoteHostname];
					}
					errorCode = AFNetworkSecureErrorServerCertificateHasUnknownRoot;
					break;
				}
			}
			
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									   errorDescription, NSLocalizedDescriptionKey,
									   underlyingError, NSUnderlyingErrorKey,
									   nil];
			return [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:errorCode userInfo:errorInfo];
		}
	}
	
#undef AFNetworkErrorCodeInRange
	
	return error;
}

#undef AFNetworkStreamNotConnectedToInternetErrorDescription
#undef AFNetworkStreamCouldntConnectToServerErrorDescription
