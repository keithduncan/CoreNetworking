//
//  AFNetworkService-PrivateFunctions.m
//  CoreNetworking
//
//  Created by Keith Duncan on 05/02/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFNetworkService-PrivateFunctions.h"

#import <objc/message.h>

#import "AFNetworkServiceScope.h"
#import "AFNetworkServiceSource.h"
#import "AFNetworkSchedule.h"

#import "AFNetwork-Constants.h"

DNSServiceErrorType _AFNetworkServiceScopeFullname(AFNetworkServiceScope *scope, NSString **fullnameRef) {
	NSCParameterAssert(fullnameRef != NULL);
	
	char fullnameBuffer[kDNSServiceMaxDomainName];
	DNSServiceErrorType fullnameError = DNSServiceConstructFullName(fullnameBuffer, [scope.name UTF8String], [scope.type UTF8String], [scope.domain UTF8String]);
	if (fullnameError != kDNSServiceErr_NoError) {
		return fullnameError;
	}
	
	*fullnameRef = [NSString stringWithCString:fullnameBuffer encoding:NSUTF8StringEncoding];
	return kDNSServiceErr_NoError;
}

/*
 
 */

BOOL _AFNetworkServiceCheckAndForwardError(id self, id delegate, SEL delegateSelector, int32_t errorCode) {
	if (errorCode == kDNSServiceErr_NoError) {
		return YES;
	}
	
	NSError *underlyingError = [NSError errorWithDomain:[AFCoreNetworkingBundleIdentifier stringByAppendingString:@".dns-sd"] code:errorCode userInfo:nil];
	
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
#warning complete this error
							   underlyingError, NSUnderlyingErrorKey,
							   nil];
	NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkServiceErrorUnknown userInfo:errorInfo];
	
	((void (*)(id, SEL, id, NSError *))objc_msgSend)(delegate, delegateSelector, self, error);
	
	return NO;
}

/*
 
 */

AFNetworkServiceSource *_AFNetworkServiceSourceForSchedule(DNSServiceRef service, AFNetworkSchedule *schedule) {
	NSCParameterAssert(service != NULL);
	NSCParameterAssert(schedule != nil);
	
	AFNetworkServiceSource *newServiceSource = [[[AFNetworkServiceSource alloc] initWithService:service] autorelease];
	
	if (schedule->_runLoop != nil) {
		[newServiceSource scheduleInRunLoop:schedule->_runLoop forMode:schedule->_runLoopMode];
	}
	else if (schedule->_dispatchQueue != NULL) {
		dispatch_queue_t queue = schedule->_dispatchQueue;
		[newServiceSource scheduleInQueue:queue];
	}
	
	return newServiceSource;
}
