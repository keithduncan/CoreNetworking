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
	@abstract	common transport layer types can be defined using these two fields
	@field		|socketType| should be one of the socket types defined in <socket.h>
	@field		|protocol| should typically be one of the IP protocols defined in RFC 1700 see http://www.faqs.org/rfcs/rfc1700.html - it is important that an appropriate |socketType| is also provided
 */
struct AFSocketTransportType {
	SInt32 socketType;
	SInt32 protocol;
};
typedef struct AFSocketTransportType AFSocketTransportType;

/*!
    @const 
    @abstract   this is suitable for creating a TCP socket
*/
extern const AFSocketTransportType AFSocketTransportTypeTCP;

/*!
	@const 
	@abstract   this is suitable for creating a UDP socket
 */
extern const AFSocketTransportType AFSocketTransportTypeUDP;

/*!
	@struct
	@abstract	A transport layer struct simply includes the post number too, the port number isn't included in the <tt>AFSocketType</tt> because it is useful without it
	@field		|type| see the documentation on <tt>AFSocketType</tt>
	@field		|port| identifies the Transport Layer address to communicate using (see RFC 1122) in network byte order
 */
struct AFSocketTransportSignature {
	const AFSocketTransportType *type;
	SInt32 port;
};
typedef struct AFSocketTransportSignature AFSocketTransportSignature;

/*!
	@const
 */
const AFSocketTransportSignature AFSocketTransportSignatureHTTP;

/*!
	@const
 */
const AFSocketTransportSignature AFSocketTransportSignatureHTTPS;

/*!
	@struct 
	@abstract   Based on CFSocketSignature allowing for higher-level functionality
	@discussion Doesn't include a |protocolFamily| field like CFSocketSignature because the |host| may resolve to a number of different protocol family addresses
	@field      |host| is copied using CFHostCreateCopy() the addresses property is resolved if it hasn't been already. The member is qualified __strong, so that if this struct is stored on the heap it won't be reclaimed
	@field		|transport| see the documentation for <tt>AFSocketTransportLayer</tt> it encapsulates the transport type (TCP/UDP/SCTP/DCCP etc) and the port
 */
struct AFSocketPeerSignature {
	/*
	 *	This defines _where_ to communicate
	 */
	__strong CFHostRef host;
	/*
	 *	This defines _how_ to communicate (and may allow for the return of a specific handler subclass from the creation methods)
	 */	
	AFSocketTransportSignature transport;
};
typedef struct AFSocketPeerSignature AFSocketPeerSignature;
