//
//  AFNetworkConstants.h
//  Amber
//
//  Created by Keith Duncan on 08/03/2009.
//  Copyright 2009. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\const
	
 */
extern NSString *const AFCoreNetworkingBundleIdentifier;

/*!
	\enum
	
 */
enum {
	// AFNetworkError									 [0, -99]
	AFNetworkErrorUnknown								= 0,
	AFNetworkErrorNotConnectedToInternet				= -1,
	AFNetworkErrorNetworkConnectionLost					= -2,
	
	// AFNetworkSocketError								 [-100, -299]
	AFNetworkSocketErrorUnknown							= -100,
	AFNetworkSocketErrorTimeout							= -101,
	
	// AFNetworkStreamError								 [-300, -399]
	AFNetworkStreamErrorUnknown							= -300,
	
	// AFNetworkTransportError							 [-400, -499]
	AFNetworkTransportErrorUnknown						= -400,
	AFNetworkTransportErrorTimeout						= -401,
	AFNetworkTransportErrorTLS							= -402,
	
	// AFNetworkConnectionError							 [-500, -599]
	AFNetworkConnectionErrorUnknown						= -500,
	AFNetworkConnectionErrorTimeout						= -501,
	
	// AFPacketError									 [-600, -799]
	AFNetworkPacketErrorUnknown							= -600,
	AFNetworkPacketErrorTimeout							= -601,
	AFNetworkPacketErrorParse							= -602,
	
	// AFNetworkSecureError								 [-2000, -2099]
	AFNetworkSecureErrorConnectionFailed				= -2100,
	AFNetworkSecureErrorServerCertificateExpired		= -2101,
	AFNetworkSecureErrorServerCertificateNotYetValid	= -2102,
	
	AFNetworkSecureErrorServerCertificateUntrusted		= -2103,
	AFNetworkSecureErrorServerCertificateHasUnknownRoot = -2104,
	
	AFNetworkSecureErrorClientCertificateRequired		= -2105,
	AFNetworkSecureErrorClientCertificateRejected		= -2106,
};
typedef NSInteger AFNetworkErrorCode;
