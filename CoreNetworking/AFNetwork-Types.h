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
	const int32_t socketType;
	const int32_t protocol;
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
AFNETWORK_EXTERN const AFNetworkSocketSignature AFNetworkSocketSignatureInternetTCP;

/*!
	\brief
	This is suitable for creating a network UDP socket.
 */
AFNETWORK_EXTERN const AFNetworkSocketSignature AFNetworkSocketSignatureInternetUDP;


/*
	AFNetworkTransport types
 */

/*!
	\brief
	A transport layer struct simply includes the post number too, the port number isn't included in the <tt>AFSocketType</tt> because it is useful without it.
 
	\field type
	See the documentation on <tt>AFSocketType</tt>.
	
	\field port
	Identifies the Transport Layer address to communicate using (see IETF-RFC-1122 <http://tools.ietf.org/html/rfc1122> in network byte order.
 */
struct _AFNetworkInternetTransportSignature {
	const AFNetworkSocketSignature type;
	uint16_t port;
};
typedef struct _AFNetworkInternetTransportSignature AFNetworkInternetTransportSignature;


/*
	AFNetwork types
 */

/*!
	\brief
	Based on CFSocketSignature allowing for higher-level functionality.
	The un-intuitive layout of the structure is very important; because the first pointer is a <tt>CFType</tt>, the structure can be introspected using <tt>CFGetTypeID()</tt>.
	
	\details
	Doesn't include a <tt>protocolFamily</tt> field like CFSocketSignature because a host may resolve to a number of addresses each with a different protocol family.
	
	\field host
	Clients receiving this struct should should copy this field using <tt>CFHostCreateCopy()</tt>. The addresses property should be resolved if it hasn't been already.
	
	\field transport
	See the documentation for <tt>AFNetworkTransportLayer</tt>, it encapsulates the transport type (TCP/UDP/SCTP/DCCP etc.) and the port.
 */
struct _AFNetworkHostSignature {
	/*
		This defines _where_ to communicate
	 */
	AFNETWORK_STRONG __attribute__((NSObject)) CFHostRef host;
	/*
		This defines _how_ to communicate.
	 */
	const AFNetworkInternetTransportSignature transport;
};
typedef struct _AFNetworkHostSignature AFNetworkHostSignature;

/*!
	\brief
	This is a partner to <tt>AFNetworkTransportHostSignature</tt> except that a <tt>CFNetServiceRef</tt> is self describing and doesn't require a <tt>transport</tt> field.
 */
struct _AFNetworkServiceSignature {
	/*
		This defines _where_ and _how_ to communicate
	 */
	AFNETWORK_STRONG __attribute__((NSObject)) CFNetServiceRef service;
};
typedef struct _AFNetworkServiceSignature AFNetworkServiceSignature;

/*!
	\brief
	Allows for implemetations to accept either <tt>AFNetworkHostSignature</tt> or <tt>AFNetworkServiceSignature</tt>.
	A receiver will introspect the type using <tt>CFGetTypeID()</tt> to determine which has been passed.
 */
typedef union _AFNetworkSignature {
	AFNetworkHostSignature *_host;
	AFNetworkServiceSignature *_service;
} AFNetworkSignature __attribute__((transparent_union));
