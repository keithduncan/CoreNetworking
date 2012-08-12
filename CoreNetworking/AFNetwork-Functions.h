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

@class AFNetworkStream;

/*
	BSD Networking
 */

/*!
	\brief
	Read the port field from an Internet address family socket address.
	The port is converted into host byte order.
 */
AFNETWORK_EXTERN uint16_t af_sockaddr_in_read_port(const struct sockaddr_storage *addr);
/*!
	\brief
	Write the port field to an Internet address familty socket address.
	The port is converted into network byte order.
 */
AFNETWORK_EXTERN void af_sockaddr_in_write_port(struct sockaddr_storage *addr, uint16_t port);

/*!
	\brief
	
 */
AFNETWORK_EXTERN bool af_sockaddr_compare(const struct sockaddr_storage *addr_a, const struct sockaddr_storage *addr_b);

/*!
	\brief
	Convert network form into presentation form.
 */
AFNETWORK_EXTERN int af_sockaddr_ntop(const struct sockaddr_storage *addr, char *destination, size_t destinationSize);

/*!
	\brief
	Convert presentation form into machine form.
 */
AFNETWORK_EXTERN int af_sockaddr_pton(const char *presentation, struct sockaddr_storage *storage);

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
AFNETWORK_EXTERN NSError *AFNetworkStreamPrepareDisplayError(AFNetworkStream *stream, NSError *error);
