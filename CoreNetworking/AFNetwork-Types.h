//
//  AFNetworkTypes.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif /* TARGET_OS_IPHONE */

#import "CoreNetworking/AFNetwork-Macros.h"

/*
	AFNetworkSocket types
 */

/*!
	\brief
	Common transport layer types can be defined using these two fields.
	
	\field socketType
	One of the socket types defined in <sys/socket.h>
	
	\field protocol
	One of the 'PROTOCOL NUMBERS' defined in IETF-RFC-1700 <http://tools.ietf.org/html/rfc1700> - it is important that an appropriate `socketType` is also provided.
 */
struct _AFNetworkSocketSignature {
	int32_t const socketType;
	int32_t const protocol;
};
typedef struct _AFNetworkSocketSignature AFNetworkSocketSignature;

/*!
	\brief
	Simple equality test.
 */
static inline BOOL AFNetworkSocketSignatureEqualToSignature(AFNetworkSocketSignature lhs, AFNetworkSocketSignature rhs) {
	return (memcmp(&lhs, &rhs, sizeof(AFNetworkSocketSignature)) == 0);
}

/*!
	\brief
	This is suitable for creating a network TCP socket.
*/
AFNETWORK_EXTERN AFNetworkSocketSignature const AFNetworkSocketSignatureInternetTCP;

/*!
	\brief
	This is suitable for creating a network UDP socket.
 */
AFNETWORK_EXTERN AFNetworkSocketSignature const AFNetworkSocketSignatureInternetUDP;


/*
	AFNetworkTransport types
 */

/*!
	\brief
	A transport layer struct simply includes the post number too, the port number isn't included in the `AFNetworkSocketType` because it is useful without it.
 
	\field type
	See the documentation on `AFNetworkSocketType`.
	
	\field port
	Identifies the Transport Layer address to communicate using (see IETF-RFC-1122 <http://tools.ietf.org/html/rfc1122> in network byte order.
 */
struct _AFNetworkInternetTransportSignature {
	AFNetworkSocketSignature const type;
	uint16_t port;
};
typedef struct _AFNetworkInternetTransportSignature AFNetworkInternetTransportSignature;


/*
	AFNetwork types
 */

/*!
	\brief
	Based on CFSocketSignature allowing for higher-level functionality.
	The un-intuitive layout of the structure is very important; because the first pointer is a `CFType`, the structure can be introspected using `CFGetTypeID()`.
	
	\details
	Doesn't include a `protocolFamily` field like CFSocketSignature because a host may resolve to a number of addresses each with a different protocol family.
	
	\field host
	Clients receiving this struct should should copy this field using `CFHostCreateCopy()`. The addresses property should be resolved if it hasn't been already.
	
	\field transport
	See the documentation for `AFNetworkTransportLayer`, it encapsulates the transport type (TCP/UDP/SCTP/DCCP etc.) and the port.
 */
struct _AFNetworkHostSignature {
	/*
		This defines _where_ to communicate
	 */
	AFNETWORK_STRONG CFHostRef host;
	/*
		This defines _how_ to communicate.
	 */
	AFNetworkInternetTransportSignature const transport;
};
typedef struct _AFNetworkHostSignature AFNetworkHostSignature;

/*!
	\brief
	This is a partner to `AFNetworkTransportHostSignature` except that a `CFNetServiceRef` is self describing and doesn't require a `transport` field.
 */
struct _AFNetworkServiceSignature {
	/*
		This defines _where_ and _how_ to communicate
	 */
	AFNETWORK_STRONG CFNetServiceRef service;
};
typedef struct _AFNetworkServiceSignature AFNetworkServiceSignature;

/*!
	\brief
	Allows for implemetations to accept either `AFNetworkHostSignature` or `AFNetworkServiceSignature`.
	A receiver will introspect the type using `CFGetTypeID()` to determine which has been passed.
 */
union _AFNetworkSignature {
	AFNetworkHostSignature *_host;
	AFNetworkServiceSignature *_service;
};
typedef union _AFNetworkSignature AFNetworkSignature __attribute__((transparent_union));
