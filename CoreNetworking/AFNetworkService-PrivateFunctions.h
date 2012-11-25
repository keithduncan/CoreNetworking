//
//  AFNetworkService-PrivateFunctions.h
//  CoreNetworking
//
//  Created by Keith Duncan on 05/02/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <dns_sd.h>

#import "CoreNetworking/AFNetworkService-Constants.h"
#import "CoreNetworking/AFNetwork-Macros.h"

@class AFNetworkServiceScope;
@class AFNetworkServiceSource;

AFNETWORK_EXTERN DNSServiceErrorType _AFNetworkServiceScopeFullname(AFNetworkServiceScope *scope, NSString **fullnameRef);

AFNETWORK_EXTERN AFNetworkServiceRecordType _AFNetworkServiceRecordNameForRecordType(uint16_t record);
AFNETWORK_EXTERN uint16_t _AFNetworkServiceRecordTypeForRecordName(AFNetworkServiceRecordType recordName);

/*
 
 */

/*
	\brief
	Check for an error from a <dns_sd.h> API function.
	
	\details
	Forward onto the delegate argument if an error has occurred, delegate selector must be of the form `networkService:didReceiveError:`
*/
AFNETWORK_EXTERN BOOL AFNetworkServiceCheckAndForwardError(id self, id delegate, SEL delegateSelector, int32_t errorCode);

/*
 
 */

struct _AFNetworkServiceSourceEnvironment {
	AFNETWORK_STRONG CFTypeRef _runLoopSource;
	void *_dispatchSource;
};
typedef struct _AFNetworkServiceSourceEnvironment _AFNetworkServiceSourceEnvironment;

AFNETWORK_EXTERN void _AFNetworkServiceSourceEnvironmentScheduleInRunLoop(_AFNetworkServiceSourceEnvironment *sourceEnvironment, NSRunLoop *runLoop, NSString *runLoopMode);
AFNETWORK_EXTERN void _AFNetworkServiceSourceEnvironmentUnscheduleFromRunLoop(_AFNetworkServiceSourceEnvironment *sourceEnvironment, NSRunLoop *runLoop, NSString *runLoopMode);

#if defined(DISPATCH_API_VERSION)

AFNETWORK_EXTERN void _AFNetworkServiceSourceEnvironmentScheduleInQueue(_AFNetworkServiceSourceEnvironment *sourceEnvironment, dispatch_queue_t queue);

#endif /* defined(DISPATCH_API_VERSION) */

AFNETWORK_EXTERN BOOL _AFNetworkServiceSourceEnvironmentIsScheduled(_AFNetworkServiceSourceEnvironment *sourceEnvironment);
AFNETWORK_EXTERN void _AFNetworkServiceSourceEnvironmentCleanup(_AFNetworkServiceSourceEnvironment *sourceEnvironment);

/*
 
 */

AFNETWORK_EXTERN AFNetworkServiceSource *_AFNetworkServiceSourceEnvironmentServiceSource(void *service, _AFNetworkServiceSourceEnvironment *sourceEnvironment);
