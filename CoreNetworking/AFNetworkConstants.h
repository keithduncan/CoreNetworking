//
//  AFNetworkConstants.h
//  Amber
//
//  Created by Keith Duncan on 08/03/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@const
 */
extern NSString *const AFCoreNetworkingBundleIdentifier;

/*!
	@enum
 */
enum {
	AFNetworkingErrorUnknown				= 0,
	
	// AFNetworkSocketError					 [100, 299]
	AFNetworkSocketErrorUnknown				= 101,
	AFNetworkSocketErrorTimeout				= 102,
	
	// AFNetworkTransportError				 [300, 499]
	AFNetworkTransportErrorUnknown			= 301,
	AFNetworkTransportErrorReachability		= 302,
	AFNetworkTransportErrorTimeout			= 303,
	AFNetworkTransportErrorTLS				= 304,
	
	// AFPacketError						 [500, 699]
	AFNetworkPacketErrorUnknown				= 500,
	AFNetworkPacketErrorParse				= 501,
};
typedef NSInteger AFNetworkingErrorCode;
