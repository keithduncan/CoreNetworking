//
//  AFHTTPMessagePacket.h
//  Amber
//
//  Created by Keith Duncan on 15/06/2009.
//  Copyright 2009. All rights reserved.
//

#import "CoreNetworking/AFPacket.h"

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif

@class AFPacketRead;

/*!
	@brief
	This packet will read either a request or response and return a CFHTTPMessageRef as it's buffer.
 */
@interface AFHTTPMessagePacket : AFPacket <AFPacketReading> {
 @private
	__strong CFHTTPMessageRef _message;
	AFPacket *_currentRead;
}

/*!
	@brief
	Designated Initialiser.
 */
- (id)initForRequest:(BOOL)isRequest;

@end
