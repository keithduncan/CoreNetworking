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

AFNetworkServiceScope *_AFNetworkServiceBrowserParseEscapedRecord(uint16_t rdlen, uint8_t const *rdata) {
	NSMutableArray *labels = [NSMutableArray arrayWithCapacity:3];
	
	uint16_t cumulativeLength = 0;
	while (cumulativeLength < rdlen) {
		uint8_t const *lengthByteRef = (rdata + cumulativeLength);
		cumulativeLength++;
		
		uint8_t labelLength = *lengthByteRef;
		if (labelLength == 0) {
			continue;
		}
		
		/*
			Note
			
			top two bits are rdata extensions this function cannot support because we don't have the full response packet to calculate offsets from
			
			0b11xxxxxx is an offset inside the DNS response packet to another label to save duplicating it
			0b01xxxxxx is an undefined extension
			0b10xxxxxx is an undefined extension
			
			therefore the maximum label size value is (2^6)-1 == 63
		 */
		uint8_t maximumLabelLength = 63;
		if (labelLength > maximumLabelLength) {
			return nil;
		}
		
		if ((cumulativeLength + labelLength) > rdlen) {
			return nil;
		}
		
		uint8_t const *labelBytes = (rdata + cumulativeLength);
		cumulativeLength += labelLength;
		
		NSString *currentLabel = [[[NSString alloc] initWithBytes:labelBytes length:labelLength encoding:NSUTF8StringEncoding] autorelease];
		if (currentLabel == nil) {
			return nil;
		}
		
		[labels addObject:currentLabel];
	}
	
	/*
		Note:
		
		the first two labels are taken as the type
		
		anything after them is taken as the domain
		
		we must have at least three labels
	 */
	if ([labels count] < 3) {
		return nil;
	}
	
	NSArray *typeLabels = [labels subarrayWithRange:NSMakeRange(0, 2)];
	NSString *type = [typeLabels componentsJoinedByString:@"."];
	if (![type hasSuffix:@"."]) {
		type = [type stringByAppendingString:@"."];
	}
	
	NSArray *domainLabels = [labels subarrayWithRange:NSMakeRange([typeLabels count], [labels count] - [typeLabels count])];
	NSString *domain = [domainLabels componentsJoinedByString:@"."];
	if (![domain hasSuffix:@"."]) {
		domain = [domain stringByAppendingString:@"."];
	}
	
	return [[[AFNetworkServiceScope alloc] initWithDomain:domain type:type name:nil] autorelease];
}
