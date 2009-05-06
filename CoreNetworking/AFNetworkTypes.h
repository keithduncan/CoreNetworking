//
//  AFNetworkTypes.h
//  Amber
//
//  Created by Keith Duncan on 15/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@struct
	@brief	common transport layer types can be defined using these two fields
	@field		|socketType| should be one of the socket types defined in <socket.h>
	@field		|protocol| should typically be one of the IP protocols defined in RFC 1700 see http://www.faqs.org/rfcs/rfc1700.html - it is important that an appropriate |socketType| is also provided
 */
struct AFNetworkSocketSignature {
	SInt32 socketType;
	SInt32 protocol;
};
typedef struct AFNetworkSocketSignature AFNetworkSocketSignature;

/*!
    @const 
    @brief   this is suitable for creating a TCP socket
*/
extern const AFNetworkSocketSignature AFNetworkSocketSignatureTCP;

/*!
	@const 
	@brief   this is suitable for creating a UDP socket
 */
extern const AFNetworkSocketSignature AFNetworkSocketSignatureUDP;

/*!
	@struct
	@brief	A transport layer struct simply includes the post number too, the port number isn't included in the <tt>AFSocketType</tt> because it is useful without it
	@field		|type| see the documentation on <tt>AFSocketType</tt>
	@field		|port| identifies the Transport Layer address to communicate using (see RFC 1122) in network byte order
 */
struct AFNetworkTransportSignature {
	const AFNetworkSocketSignature *type;
	SInt32 port;
};
typedef struct AFNetworkTransportSignature AFNetworkTransportSignature;

/*!
	@const
 */
const AFNetworkTransportSignature AFNetworkTransportSignatureHTTP;

/*!
	@const
 */
const AFNetworkTransportSignature AFNetworkTransportSignatureHTTPS;

/*!
	@struct 
	@brief   Based on CFSocketSignature allowing for higher-level functionality
	@detail Doesn't include a |protocolFamily| field like CFSocketSignature because the |host| may resolve to a number of different protocol family addresses
	@field      |host| is copied using CFHostCreateCopy() the addresses property is resolved if it hasn't been already. The member is qualified __strong, so that if this struct is stored on the heap it won't be reclaimed
	@field		|transport| see the documentation for <tt>AFSocketTransportLayer</tt> it encapsulates the transport type (TCP/UDP/SCTP/DCCP etc) and the port
 */
struct AFNetworkTransportPeerSignature {
	/*
	 *	This defines _where_ to communicate
	 */
	__strong CFHostRef host;
	/*
	 *	This defines _how_ to communicate (and may allow for the return of a specific handler subclass from the creation methods)
	 */	
	AFNetworkTransportSignature transport;
};
typedef struct AFNetworkTransportPeerSignature AFNetworkTransportPeerSignature;
