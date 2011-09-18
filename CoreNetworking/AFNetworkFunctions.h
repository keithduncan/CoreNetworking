//
//  AFNetworkFunctions.h
//  Bonjour
//
//  Created by Keith Duncan on 02/01/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <sys/socket.h>

@class AFNetworkStream;

/*
	BSD Networking
 */

/*!
	\brief
	
 */
extern bool af_sockaddr_compare(const struct sockaddr *addr_a, const struct sockaddr *addr_b);

/*!
	\brief
	This may be a lossy conversion and should only be used for showing addresses to the user
	
	You MUST not attempt to convert these representtions back into a `struct sockaddr`
 */
extern const char *af_sockaddr_ntop(const struct sockaddr *addr, char *dst, size_t maxlen);

/*
	Cocoa Networking
 */

/*!
	\brief
	Wrap `af_sockaddr_ntop()` with Cocoa level objects.
 */
extern NSString *AFNetworkSocketAddressToPresentation(NSData *socketAddress);

/*!
	\brief
	
 */
extern NSError *AFNetworkStreamPrepareError(AFNetworkStream *stream, NSError *error);
