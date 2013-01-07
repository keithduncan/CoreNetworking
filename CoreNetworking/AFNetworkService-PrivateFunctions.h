//
//  AFNetworkService-PrivateFunctions.h
//  CoreNetworking
//
//  Created by Keith Duncan on 05/02/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <dns_sd.h>

#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkServiceScope;
@class AFNetworkServiceSource;
@class AFNetworkSchedule;

/*!
	\brief
	
 */
AFNETWORK_EXTERN DNSServiceErrorType _AFNetworkServiceScopeFullname(AFNetworkServiceScope *scope, NSString **fullnameRef);

/*
	\brief
	Check for an error from a <dns_sd.h> API function.
	
	\details
	Forward onto the delegate argument if an error has occurred, delegate selector must be of the form `networkService:didReceiveError:`
*/
AFNETWORK_EXTERN BOOL _AFNetworkServiceCheckAndForwardError(id self, id delegate, SEL delegateSelector, int32_t errorCode);

/*!
	\brief
	
 */
AFNETWORK_EXTERN AFNetworkServiceSource *_AFNetworkServiceSourceForSchedule(DNSServiceRef service, AFNetworkSchedule *schedule);

/*!
	\brief
	
 */
AFNETWORK_EXTERN AFNetworkServiceScope *_AFNetworkServiceBrowserParseEscapedRecord(uint16_t rdlen, uint8_t const *rdata);
