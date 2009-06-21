//
//  AFHTTPMessagePacket.h
//  Amber
//
//  Created by Keith Duncan on 15/06/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

@class AFPacketRead;

/*!
	@brief
	This function returns the expected body length of the provided CFHTTPMessageRef.
 
	This method uses the "Content-Length" header of the response to determine how much more a client should read to complete the packet.
	If CFHTTPMessageIsHeaderComplete(self.response) returns false, this method returns -1.
 */
extern NSInteger AFHTTPMessageGetHeaderLength(CFHTTPMessageRef message);

/*!
	@brief
	This packet will read either a request or response and return a CFHTTPMessageRef as it's buffer.
 */
@interface AFHTTPMessagePacket : AFPacket <AFPacketReading> {
	__strong CFHTTPMessageRef _message;
	AFPacketRead *_currentRead;
}

- (id)initForRequest:(BOOL)isRequest;

@end
