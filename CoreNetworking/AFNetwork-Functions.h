//
//  AFNetworkFunctions.h
//  Bonjour
//
//  Created by Keith Duncan on 02/01/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <sys/socket.h>

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkStreamQueue;

/*
	BSD Networking
 */

/*!
	\brief
	Read the port field from an Internet address family socket address.
	The port is converted to host byte order for return.
	
	\details
	Use of this function should be avoided as it assumes the layout of the socket address,
	its better to use <x-man-page://getaddrinfo> and <x-man-page://getnameinfo> to avoid hard
	coding address families into the userspace
 */
AFNETWORK_EXTERN uint16_t af_sockaddr_in_read_port(struct sockaddr_storage const *addr);
/*!
	\brief
	Write the port field to an Internet address familty socket address.
	The port is converted into network byte order.
	
	\details
	See also the details for af_sockaddr_in_read_port for advisory notice.
 */
AFNETWORK_EXTERN void af_sockaddr_in_write_port(struct sockaddr_storage *addr, uint16_t port);

/*!
	\brief
	Compare addresses in an address family aware manner, accomodating for IPv6 mapped IPv4 addresses and wildcard addresses and ports
 */
AFNETWORK_EXTERN bool af_sockaddr_compare(struct sockaddr_storage const *addr_a, struct sockaddr_storage const *addr_b);

/*!
	\brief
	Convert network form into presentation form.
 */
AFNETWORK_EXTERN int af_sockaddr_ntop(struct sockaddr_storage const *addr, char *destination, socklen_t destinationSize);

/*!
	\brief
	Convert presentation form into machine form.
 */
AFNETWORK_EXTERN int af_sockaddr_pton(char const *presentation, struct sockaddr_storage *storage);

/*
	Cocoa Networking
 */

/*!
	\brief
	Wrap `af_sockaddr_ntop()` with Cocoa level objects and error handling.
 */
AFNETWORK_EXTERN NSString *AFNetworkSocketAddressToPresentation(NSData *socketAddress, NSError **errorRef);

/*!
	\brief
	This API is not lossy, you MAY convert the result back to a presentation format.
	Not all address families are supported.
	Wrap `af_sockaddr_pton()` with Cocoa level objects.
 */
AFNETWORK_EXTERN NSData *AFNetworkSocketPresentationToAddress(NSString *presentation, NSError **errorRef);

/*!
	\brief
	It is highly unlikely that you will ever need to use this function.
	This function should never be used to decide whether to attempt a connection, only to determine whether the cause of an error was due to reachability.
	This function should only be used where using CFNetworkIsConnectedToInternet() would be appropriate.
 */
AFNETWORK_EXTERN BOOL AFNetworkIsConnectedToInternet(void);

/*!
	\brief
	Errors from AFNetworkStream are raw and unsuitable for display to the user, this function attempts to generate a legible error.
 */
AFNETWORK_EXTERN NSError *AFNetworkStreamPrepareDisplayError(AFNetworkStreamQueue *stream, NSError *error);
