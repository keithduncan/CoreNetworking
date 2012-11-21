//
//  AFHTTPHeadersPacket.h
//  Amber
//
//  Created by Keith Duncan on 01/03/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif /* TARGET_OS_IPHONE */

#import "CoreNetworking/AFNetworkPacket.h"

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkPacketRead;

/*!
	\brief
	This function returns the expected body length of the provided CFHTTPMessageRef.
 
	This method uses the "Content-Length" header of the response to determine how much more a client should read to complete the packet.
	If CFHTTPMessageIsHeaderComplete(self.response) returns false, this method returns -1.
 */
AFNETWORK_EXTERN NSInteger AFHTTPMessageGetExpectedBodyLength(CFHTTPMessageRef message);

/*!
	\brief
	Read upto the end of the empty line and following \r\n before the body starts
 */
@interface AFHTTPHeadersPacket : AFNetworkPacket <AFNetworkPacketReading> {
 @private
	AFNETWORK_STRONG __attribute__((NSObject)) CFHTTPMessageRef _message;
	AFNetworkPacketRead *_currentRead;
}

/*!
	\brief
	Designated Initialiser.
 */
- (id)initWithMessage:(CFHTTPMessageRef)message;

@end
