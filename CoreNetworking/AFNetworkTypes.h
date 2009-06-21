//
//  AFNetworkTypes.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

/*!
	@brief
	Common transport layer types can be defined using these two fields.
	
	@field |socketType|
	Should be one of the socket types defined in <sys/socket.h>
	@field |protocol|
	Should typically be one of the IP protocols defined in RFC 1700 see http://www.faqs.org/rfcs/rfc1700.html - it is important that an appropriate |socketType| is also provided.
 */
struct AFSocketSignature {
	const SInt32 socketType;
	const SInt32 protocol;
};
typedef struct AFSocketSignature AFSocketSignature;

/*!
    @brief
	This is suitable for creating a network TCP socket.
*/
extern const AFSocketSignature AFNetworkSocketSignatureTCP;

/*!
	@brief
	This is suitable for creating a network UDP socket.
 */
extern const AFSocketSignature AFNetworkSocketSignatureUDP;

/*!
	@brief
	This is suitable for creating a local UNIX socket.
 */
extern const AFSocketSignature AFLocalSocketSignature;

/*!
	@brief
	A transport layer struct simply includes the post number too, the port number isn't included in the <tt>AFSocketType</tt> because it is useful without it.
 
	@field |type|
	See the documentation on <tt>AFSocketType</tt>.
	@field |port|
	Identifies the Transport Layer address to communicate using (see RFC 1122) in network byte order.
 */
struct AFInternetTransportSignature {
	const AFSocketSignature *type;
	SInt32 port;
};
typedef struct AFInternetTransportSignature AFInternetTransportSignature;

extern const AFInternetTransportSignature AFInternetTransportSignatureHTTP;
extern const AFInternetTransportSignature AFInternetTransportSignatureHTTPS;

/*!
	@brief
	Based on CFSocketSignature allowing for higher-level functionality.
	The un-intuitive layout of the structure is very important; because the first pointer width bits are a CFTypeRef the structure can be introspected using CFGetTypeID.
	
	@detail
	Doesn't include a |protocolFamily| field like CFSocketSignature because the |host| may resolve to a number of different protocol family addresses.
	
	@field
	|host| is copied using CFHostCreateCopy() the addresses property is resolved if it hasn't been already. The member is qualified __strong, so that if this struct is stored on the heap or as an instance variable, it won't be reclaimed.
	@field
	|transport| see the documentation for <tt>AFNetworkTransportLayer</tt>, it encapsulates the transport type (TCP/UDP/SCTP/DCCP etc) and the port.
 */
struct AFNetworkTransportPeerSignature {
	/*
	 *	This defines _where_ to communicate
	 */
	__strong CFHostRef host;
	/*
	 *	This defines _how_ to communicate (and may allow for the return of a specific handler subclass from the creation methods)
	 */
	const AFInternetTransportSignature *transport;
};
typedef struct AFNetworkTransportPeerSignature AFNetworkTransportPeerSignature;
