//
//  AFNetworkConstants.h
//  Amber
//
//  Created by Keith Duncan on 08/03/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

/*!
	\const
	
 */
AFNETWORK_EXTERN NSString *const AFCoreNetworkingBundleIdentifier;

/*!
	\enum
	
 */
typedef AFNETWORK_ENUM(NSInteger, AFNetworkErrorCode) {
	// AFNetworkError									 [0, -99]
	AFNetworkErrorUnknown								= 0,
	AFNetworkErrorNotConnectedToInternet				= -1,
	AFNetworkErrorNetworkConnectionLost					= -2,
	
	// AFNetworkHostError								 [-100, -199]
	AFNetworkHostErrorUnknown							= -100,
	AFNetworkHostErrorInvalid							= -101,
	AFNetworkHostErrorCannotConnect						= -102,
	AFNetworkHostErrorTimeout							= -103,
	
	// AFNetworkServiceError							 [-200, -299]
	AFNetworkServiceErrorUnknown						= -200,
	
	// AFNetworkSocketError								 [-300, -399]
	AFNetworkSocketErrorUnknown							= -300,
	AFNetworkSocketErrorListenerOpenNotPermitted		= -301,
	AFNetworkSocketErrorListenerOpenAddressAlreadyUsed	= -302,
	
	// AFNetworkStreamError								 [-400, -499]
	AFNetworkStreamErrorUnknown							= -400,
	AFNetworkStreamErrorServerClosed					= -401,
	
	// AFNetworkTransportError							 [-500, -599]
	AFNetworkTransportErrorUnknown						= -500,
	AFNetworkTransportErrorTimeout						= -501,
	AFNetworkTransportErrorTLS							= -502,
	
	// AFNetworkConnectionError							 [-600, -699]
	AFNetworkConnectionErrorUnknown						= -600,
	AFNetworkConnectionErrorTimeout						= -601,
	
	// AFNetworkPacketError								 [-700, -799]
	AFNetworkPacketErrorUnknown							= -700,
	AFNetworkPacketErrorTimeout							= -701,
	AFNetworkPacketErrorParse							= -702,
	
	// AFNetworkSecureError								 [-2000, -2099]
	AFNetworkSecureErrorConnectionFailed				= -2100,
	AFNetworkSecureErrorServerCertificateExpired		= -2101,
	AFNetworkSecureErrorServerCertificateNotYetValid	= -2102,
	
	AFNetworkSecureErrorServerCertificateUntrusted		= -2103,
	AFNetworkSecureErrorServerCertificateHasUnknownRoot = -2104,
	
	AFNetworkSecureErrorClientCertificateRequired		= -2105,
	AFNetworkSecureErrorClientCertificateRejected		= -2106,
};
