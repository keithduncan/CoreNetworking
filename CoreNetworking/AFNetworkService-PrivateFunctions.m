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

static struct _AFNetworkServiceRecordTypeToRecordName {
	uint16_t type;
	AFNetworkServiceRecordType name;
} const recordTypeToRecordNameMap[] = {
	{
		.type = kDNSServiceType_TXT,
		.name = AFNetworkServiceRecordTypeTXT,
	},
	{
		.type = kDNSServiceType_NULL,
		.name = AFNetworkServiceRecordTypeNULL,
	},
};

AFNetworkServiceRecordType _AFNetworkServiceRecordNameForRecordType(uint16_t recordType) {
	for (NSUInteger idx = 0; idx < sizeof(recordTypeToRecordNameMap)/sizeof(*recordTypeToRecordNameMap); idx++) {
		if (recordTypeToRecordNameMap[idx].type != recordType) {
			continue;
		}
		
		return recordTypeToRecordNameMap[idx].name;
	}
	
	@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"unknown record type (%hd)", recordType] userInfo:nil];
	return -1;
}

uint16_t _AFNetworkServiceRecordTypeForRecordName(AFNetworkServiceRecordType recordName) {
	for (NSUInteger idx = 0; idx < sizeof(recordTypeToRecordNameMap)/sizeof(*recordTypeToRecordNameMap); idx++) {
		if (recordTypeToRecordNameMap[idx].name != recordName) {
			continue;
		}
		
		return recordTypeToRecordNameMap[idx].type;
	}
	
	@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"unknown record name (%ld)", recordName] userInfo:nil];
	return -1;
}

/*
 
 */

BOOL AFNetworkServiceCheckAndForwardError(id self, id delegate, SEL delegateSelector, int32_t errorCode) {
	if (errorCode == kDNSServiceErr_NoError) {
		return YES;
	}
	
	NSError *underlyingError = [NSError errorWithDomain:[AFCoreNetworkingBundleIdentifier stringByAppendingString:@".dns-sd"] code:errorCode userInfo:nil];
	
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
#warning complete this error
							   underlyingError, NSUnderlyingErrorKey,
							   nil];
	NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkErrorUnknown userInfo:errorInfo];
	
	((void (*)(id, SEL, id, NSError *))objc_msgSend)(delegate, delegateSelector, self, error);
	
	return NO;
}

/*
 
 */

static NSString *const _AFNetworkServiceSourceEnvironmentRunLoopKey = @"RunLoop";
static NSString *const _AFNetworkServiceSourceEnvironmentModeKey = @"Mode";

void _AFNetworkServiceSourceEnvironmentScheduleInRunLoop(_AFNetworkServiceSourceEnvironment *sourceEnvironment, NSRunLoop *runLoop, NSString *runLoopMode) {
	NSCParameterAssert(runLoop != NULL);
	NSCParameterAssert(runLoopMode != nil);
	
	NSCParameterAssert(sourceEnvironment->_runLoopSource == NULL);
	NSCParameterAssert(sourceEnvironment->_dispatchSource == NULL);
	
	NSDictionary *schedule = [NSDictionary dictionaryWithObjectsAndKeys:
							  runLoop, _AFNetworkServiceSourceEnvironmentRunLoopKey,
							  [[runLoopMode copy] autorelease], _AFNetworkServiceSourceEnvironmentModeKey,
							  nil];
	sourceEnvironment->_runLoopSource = CFRetain(schedule);
}

void _AFNetworkServiceSourceEnvironmentUnscheduleFromRunLoop(_AFNetworkServiceSourceEnvironment *sourceEnvironment, NSRunLoop *runLoop, NSString *runLoopMode) {
	NSCParameterAssert(sourceEnvironment->_runLoopSource != NULL);
	NSCParameterAssert(sourceEnvironment->_dispatchSource != NULL);
	
	CFRelease(sourceEnvironment->_runLoopSource);
	sourceEnvironment->_runLoopSource = NULL;
}

void _AFNetworkServiceSourceEnvironmentScheduleInQueue(_AFNetworkServiceSourceEnvironment *sourceEnvironment, dispatch_queue_t queue) {
	NSCParameterAssert(sourceEnvironment->_runLoopSource == NULL);
	
	if (sourceEnvironment->_dispatchSource != NULL) {
		dispatch_release(sourceEnvironment->_dispatchSource);
		sourceEnvironment->_dispatchSource = NULL;
	}
	
	if (queue == NULL) {
		return;
	}
	
	sourceEnvironment->_dispatchSource = queue;
	dispatch_retain(queue);
}

BOOL _AFNetworkServiceSourceEnvironmentIsScheduled(_AFNetworkServiceSourceEnvironment *sourceEnvironment) {
	return ((sourceEnvironment->_runLoopSource != NULL) || (sourceEnvironment->_dispatchSource != NULL));
}

void _AFNetworkServiceSourceEnvironmentCleanup(_AFNetworkServiceSourceEnvironment *sourceEnvironment) {
	if (sourceEnvironment->_runLoopSource != NULL) {
		CFRelease(sourceEnvironment->_runLoopSource);
	}
	if (sourceEnvironment->_dispatchSource != NULL) {
		dispatch_release(sourceEnvironment->_dispatchSource);
	}
}

/*
 
 */

AFNetworkServiceSource *_AFNetworkServiceSourceEnvironmentServiceSource(void *service, _AFNetworkServiceSourceEnvironment *sourceEnvironment) {
	AFNetworkServiceSource *newServiceSource = [[[AFNetworkServiceSource alloc] initWithService:(DNSServiceRef)service] autorelease];
	
	if (sourceEnvironment->_runLoopSource != NULL) {
		NSDictionary *runLoopSource = sourceEnvironment->_runLoopSource;
		[newServiceSource scheduleInRunLoop:[runLoopSource objectForKey:_AFNetworkServiceSourceEnvironmentRunLoopKey] forMode:[runLoopSource objectForKey:_AFNetworkServiceSourceEnvironmentModeKey]];
	}
	else if (sourceEnvironment->_dispatchSource != NULL) {
		dispatch_queue_t queue = sourceEnvironment->_dispatchSource;
		[newServiceSource scheduleInQueue:queue];
	}
	
	return newServiceSource;
}
