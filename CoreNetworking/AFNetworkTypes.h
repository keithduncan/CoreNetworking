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
struct AFSocketType {
	SInt32 socketType;
	SInt32 protocol;
};
typedef struct AFSocketType AFSocketType;

/*!
    @const 
    @abstract   this is suitable for creating a TCP socket
*/
extern const AFSocketType AFSocketTypeTCP;

/*!
	@const 
	@abstract   this is suitable for creating a UDP socket
 */
extern const AFSocketType AFSocketTypeUDP;

/*!
	@struct
	@abstract	A transport layer struct simply includes the post number too, the port number isn't included in the <tt>AFSocketType</tt> because it is useful without it
	@field		|type| see the documentation on <tt>AFSocketType</tt>
	@field		|port| identifies the Transport Layer address to communicate using (see RFC 1122) in network byte order
 */
struct AFSocketTransport {
	const AFSocketType *type;
	SInt32 port;
};
typedef struct AFSocketTransport AFSocketTransport;

/*!
	@const
 */
const AFSocketTransport AFSocketTransportHTTP;

/*!
	@const
 */
const AFSocketTransport AFSocketTransportHTTPS;
