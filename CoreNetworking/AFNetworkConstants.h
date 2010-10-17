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
	AFNetworkErrorUnknown					= 0,
	
	// AFNetworkSocketError					 [100, 299]
	AFNetworkSocketErrorUnknown				= 100,
	AFNetworkSocketErrorTimeout				= 101,
	
	// AFNetworkTransportError				 [300, 499]
	AFNetworkTransportErrorUnknown			= 300,
	AFNetworkTransportErrorTimeout			= 301,
	AFNetworkTransportErrorTLS				= 302,
	
	// AFNetworkConnectionError				 [500, 599]
	AFNetworkConnectionErrorUnknown			= 500,
	AFNetworkConnectionErrorTimeout			= 501,
	
	// AFPacketError						 [600, 799]
	AFNetworkPacketErrorUnknown				= 600,
	AFNetworkPacketErrorTimeout				= 601,
	AFNetworkPacketErrorParse				= 602,
};
typedef NSInteger AFNetworkErrorCode;
