//
//  AFHTTPBodyPacket.h
//  TwitterLiveStream
//
//  Created by Keith Duncan on 23/09/2010.
//  Copyright 2010. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <CFNetwork/CFNetwork.h>
#endif /* TARGET_OS_IPHONE */

#import "CoreNetworking/AFNetworkPacket.h"

#import "CoreNetworking/AFNetwork-Macros.h"

/*!
	\brief
	Posted for each piece of data read from the input stream.
 */
AFNETWORK_EXTERN NSString *const AFHTTPBodyPacketDidReadNotificationName;
	
	AFNETWORK_EXTERN NSString *const AFHTTPBodyPacketDidReadDataKey;

/*!
	\brief
	This is a versatile packet for handling HTTP bodies.
	
	\details
	It will handle identity or chunked bodies.
 */
@interface AFHTTPBodyPacket : AFNetworkPacket <AFNetworkPacketReading> {
 @protected
	AFNETWORK_STRONG CFHTTPMessageRef _message;
	AFNetworkPacket <AFNetworkPacketReading> *_currentPacket;
	BOOL _appendBodyDataToMessage;
}

/*!
	\brief
	Should be called before creating a body packet, this is asserted in the constructor.
	
	\details
	This doesn't indicate that the body <em>can</em> be parsed, just that a body is present.
 
	\param message
	The message MUST have a complete header, or an exception is thrown.
 */
+ (BOOL)messageHasBody:(CFHTTPMessageRef)message;

/*!
	\brief
	Attempts to interpret the message header and generate an appropriate packet.
	
	\details
	If the message has an incomplete header, or `+messageHasBody:` returns NO, an exception is thrown.
 */
+ (AFHTTPBodyPacket *)parseBodyPacketFromMessage:(CFHTTPMessageRef)message error:(NSError **)errorRef;

/*!
	\brief
	Configures whether the body data should be appended to the message body passed in.
	
	\details
	Defaults to YES.
 */
@property (assign, nonatomic) BOOL appendBodyDataToMessage;

@end
