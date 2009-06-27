//
//  AFNetworkConstants.h
//  Amber
//
//  Created by Keith Duncan on 08/03/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@const
 */
extern NSString *const AFCoreNetworkingBundleIdentifier;

/*!
	@const
 */
extern NSString *const AFNetworkingErrorDomain;

/*!
	@enum
 */
enum {
	AFNetworkingErrorNone					= 0,
	
	// AFNetworkSocketError					[100, 299]
	AFSocketErrorUnknown					= 101,
	AFSocketErrorTimeout					= 102,
	
	// AFNetworkTransportError				[300, 499]
	AFNetworkTransportErrorUnknown			= 301,
	AFNetworkTransportReachabilityError		= 302,
	AFNetworkTransportReadTimeoutError		= 304,
	AFNetworkTransportWriteTimeoutError		= 305,
	AFNetworkTransportTLSError				= 306,
};
typedef NSInteger AFNetworkingErrorCode;
