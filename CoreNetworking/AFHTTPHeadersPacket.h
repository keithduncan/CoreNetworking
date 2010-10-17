//
//  AFHTTPHeadersPacket.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import "CoreNetworking/AFNetworkPacket.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

@class AFNetworkPacketRead;

/*!
	\brief
	This function returns the expected body length of the provided CFHTTPMessageRef.
 
	This method uses the "Content-Length" header of the response to determine how much more a client should read to complete the packet.
	If CFHTTPMessageIsHeaderComplete(self.response) returns false, this method returns -1.
 */
extern NSInteger AFHTTPMessageGetExpectedBodyLength(CFHTTPMessageRef message);

/*!
	\brief
	
 */
@interface AFHTTPHeadersPacket : AFNetworkPacket <AFNetworkPacketReading> {
 @private
	__strong CFHTTPMessageRef _message;
	AFNetworkPacketRead *_currentRead;
}

/*!
	\brief
	Designated Initialiser.
 */
- (id)initWithMessage:(CFHTTPMessageRef)message;

@end
