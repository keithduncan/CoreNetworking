//
//  AFHTTPMessagePacket.h
//  Amber
//
//  Created by Keith Duncan on 15/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "CoreNetworking/AFNetworkPacket.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

@class AFNetworkPacketRead;

/*!
	\brief
	This packet will read either a request or response and return a CFHTTPMessageRef as it's buffer.
	
	\details
	This is a composite packet, wrapping <tt>AFHTTPHeadersPacket</tt> and <tt>AFHTTPBodyPacket</tt>.
 */
@interface AFHTTPMessagePacket : AFNetworkPacket <AFNetworkPacketReading> {
 @private
	__strong CFHTTPMessageRef _message;
	
	NSURL *_bodyStorage;
	NSOutputStream *_bodyStream;
	
	AFNetworkPacket *_currentRead;
}

/*!
	\brief
	Designated Initialiser.
 */
- (id)initForRequest:(BOOL)isRequest;

/*!
	\brief
	By default, the response body is appended to the message buffer.
	If set, the body will be streamed to disk instead of loaded into memory.
 */
@property (copy) NSURL *bodyStorage;

@end
