//
//  AFNetworkServicePublisher.m
//  CoreNetworking
//
//  Created by Keith Duncan on 12/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import "AFNetworkServicePublisher.h"

#import <dns_sd.h>

#import "AFNetworkServiceScope.h"
#import "AFNetworkServiceScope+AFNetworkPrivate.h"
#import "AFNetworkServiceSource.h"

#import "AFNetworkService-Functions.h"
#import "AFNetworkService-PrivateFunctions.h"

/*
	Note:
	
	all NSData objects are passed via lookup in recordToDataMap instance variable
	
	this allows us to sidestep the issues caused by interior pointers
	
	as all NSData objects are strongly referenced by the map table
 */

struct _AFNetworkServicePublisher_CompileTimeAssertions {
	char assert0[(sizeof(DNSServiceRef) <= sizeof(void *) ? 1 : -1)];
	char assert1[(sizeof(AFNetworkServiceRecordType) <= sizeof(id) ? 1 : -1)];
	char assert2[(sizeof(AFNetworkServiceRecordType) <= sizeof(void *) ? 1 : -1)];
};

static BOOL _AFNetworkServicePublisherCheckAndForwardError(AFNetworkServicePublisher *self, DNSServiceErrorType errorCode) {
	return AFNetworkServiceCheckAndForwardError(self, self.delegate, @selector(networkServicePublisher:didReceiveError:), errorCode);
}

@interface AFNetworkServicePublisher ()
@property (retain, nonatomic) AFNetworkServiceScope *serviceScope;
@property (assign, nonatomic) uint32_t port;
@property (retain, nonatomic) NSMapTable *recordToDataMap;

@property (assign, nonatomic) DNSServiceRef service;
@property (readwrite, retain, nonatomic) AFNetworkServiceSource *serviceSource;

@property (retain, nonatomic) NSMapTable *recordToHandleMap;

@property (retain, nonatomic) NSMutableSet *scopes;
@end

@interface AFNetworkServicePublisher (AFNetworkPrivate)
- (NSData *)_validatedRecordDataForRecord:(AFNetworkServiceRecordType)record;
- (void)_updateDataForRecordIfRequired:(AFNetworkServiceRecordType)record;

- (void)_addScope:(AFNetworkServiceScope *)scope;
- (void)_removeScope:(AFNetworkServiceScope *)scope;
@end

@implementation AFNetworkServicePublisher

@synthesize serviceScope=_serviceScope, port=_port, recordToDataMap=_recordToDataMap;

@synthesize delegate=_delegate;

@synthesize service=_service, serviceSource=_serviceSource;

@synthesize recordToHandleMap=_recordToHandleMap;

@synthesize scopes=_scopes;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	NSPointerFunctionsOptions recordToMapKeyOptions = (NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality);
	_recordToDataMap = [[NSMapTable alloc] initWithKeyOptions:recordToMapKeyOptions valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality) capacity:0];
	_recordToHandleMap = [[NSMapTable alloc] initWithKeyOptions:recordToMapKeyOptions valueOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality) capacity:0];
	
	_scopes = [[NSMutableSet alloc] init];
	
	return self;
}

- (id)initWithServiceScope:(AFNetworkServiceScope *)serviceScope port:(uint32_t)port {
	NSParameterAssert(![serviceScope _scopeContainsWildcard]);
	/*
		Note:
		
		we must have at least a type, nil domain and name parameters are acceptable
		
		a nil name means choose one automatically
		a nil domain means all publishable domains
	 */
	NSParameterAssert([serviceScope.type length] > 0);
	
	self = [self init];
	if (self == nil) return nil;
	
	_serviceScope = [serviceScope retain];
	_port = port;
	
	return self;
}

- (void)dealloc {
	[_serviceScope release];
	[_recordToDataMap release];
	
	_AFNetworkServiceSourceEnvironmentCleanup((_AFNetworkServiceSourceEnvironment *)&_sources);
	
	if (_service != NULL) {
		DNSServiceRefDeallocate((DNSServiceRef)_service);
	}
	[_serviceSource release];
	[_recordToHandleMap release];
	
	[_scopes release];
	
	[super dealloc];
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	_AFNetworkServiceSourceEnvironmentScheduleInRunLoop((_AFNetworkServiceSourceEnvironment *)&_sources, runLoop, mode);
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	_AFNetworkServiceSourceEnvironmentUnscheduleFromRunLoop((_AFNetworkServiceSourceEnvironment *)&_sources, runLoop, mode);
}

#if defined(DISPATCH_API_VERSION)

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	_AFNetworkServiceSourceEnvironmentScheduleInQueue((_AFNetworkServiceSourceEnvironment *)&_sources, queue);
}

#endif

- (void)publishData:(NSData *)data forRecord:(AFNetworkServiceRecordType)record {
	NSParameterAssert(data != nil);
	
	NSMapInsert(self.recordToDataMap, (const void *)record, (const void *)[[data copy] autorelease]);
	
	[self _updateDataForRecordIfRequired:record];
}

- (void)removeDataForRecord:(AFNetworkServiceRecordType)record {
	NSMapRemove(self.recordToDataMap, (const void *)record);
	
	[self _updateDataForRecordIfRequired:record];
}

static void _AFNetworkServicePublisherRegisterCallback(DNSServiceRef sdRef, DNSServiceFlags flags, DNSServiceErrorType errorCode, const char *replyName, const char *replyType, const char *replyDomain, void *context) {
	AFNetworkServicePublisher *self = [[(id)context retain] autorelease];
	
	if (![self.serviceSource isValid]) {
		return;
	}
	
	if (!_AFNetworkServicePublisherCheckAndForwardError(self, errorCode)) {
		return;
	}
	
	NSString *domain = [NSString stringWithUTF8String:replyDomain];
	NSString *type = [NSString stringWithUTF8String:replyType];
	NSString *name = [NSString stringWithUTF8String:replyName];
	
	AFNetworkServiceScope *scope = [[[AFNetworkServiceScope alloc] initWithDomain:domain type:type name:name] autorelease];
	
	if ((flags & kDNSServiceFlagsAdd) == kDNSServiceFlagsAdd) {
		[self _addScope:scope];
	}
	else {
		[self _removeScope:scope];
	}
}

- (void)publish {
	AFNetworkServiceScope *scope = self.serviceScope;
	NSParameterAssert(scope != nil);
	NSParameterAssert(_sources._runLoopSource != NULL || _sources._dispatchSource != NULL);
	NSParameterAssert(self.delegate != nil);
	NSParameterAssert(self.service == NULL);
	
	NSData *TXTRecordData = [self _validatedRecordDataForRecord:AFNetworkServiceRecordTypeTXT];
	
	DNSServiceErrorType registerError = DNSServiceRegister((DNSServiceRef *)&_service, (DNSServiceFlags)0, kDNSServiceInterfaceIndexAny, [scope.name UTF8String], [scope.type UTF8String], [scope.domain UTF8String], NULL, htons(self.port), (uint16_t)[TXTRecordData length], (const void *)[TXTRecordData bytes], _AFNetworkServicePublisherRegisterCallback, self);
	if (!_AFNetworkServicePublisherCheckAndForwardError(self, registerError)) {
		return;
	}
	
	AFNetworkServiceSource *newServiceSource = _AFNetworkServiceSourceEnvironmentServiceSource(_service, (_AFNetworkServiceSourceEnvironment *)&_sources);
	self.serviceSource = newServiceSource;
	
	NSMapEnumerator recordToRecordDataEnumerator = NSEnumerateMapTable(self.recordToDataMap);
	AFNetworkServiceRecordType recordType = 0; NSData *recordData = nil;
	while (NSNextMapEnumeratorPair(&recordToRecordDataEnumerator, (void **)&recordType, (void **)&recordData)) {
		if (recordType == AFNetworkServiceRecordTypeTXT) {
			continue;
		}
		
		[self _updateDataForRecordIfRequired:recordType];
	}
	NSEndMapTableEnumeration(&recordToRecordDataEnumerator);
}

- (void)invalidate {
	[self.serviceSource invalidate];
#warning needs to remove the published records
}

@end

@implementation AFNetworkServicePublisher (AFNetworkPrivate)

- (NSData *)_validatedRecordDataForRecord:(AFNetworkServiceRecordType)record {
	NSData *recordData = NSMapGet(self.recordToDataMap, (const void *)record);
	if ([recordData length] > UINT16_MAX) {
		return nil;
	}
	return recordData;
}

- (void)_updateDataForRecordIfRequired:(AFNetworkServiceRecordType)record {
	if (_service == NULL) {
		return;
	}
	
	NSData *recordData = [self _validatedRecordDataForRecord:record];
	
	DNSRecordRef existingRecord = NSMapGet(self.recordToHandleMap, (const void *)record);
	if (existingRecord != NULL && recordData == nil) {
		DNSServiceErrorType removeRecordError = DNSServiceRemoveRecord(_service, existingRecord, (DNSServiceFlags)0);
#warning check the kind of errors we can get from this API at http://opensource.apple.com
		
		_AFNetworkServicePublisherCheckAndForwardError(self, removeRecordError);
		
		NSMapRemove(self.recordToHandleMap, (const void *)record);
		return;
	}
	
	if (existingRecord != NULL || record == AFNetworkServiceRecordTypeTXT) {
		DNSServiceErrorType updateRecordError = DNSServiceUpdateRecord(_service, existingRecord, (DNSServiceFlags)0, (uint16_t)[recordData length], (const void *)[recordData bytes], 0);
		
		if (!_AFNetworkServicePublisherCheckAndForwardError(self, updateRecordError)) {
#warning check the kind of errors we can get from this API at http://opensource.apple.com
#warning should we remove the record from recordToHandleMap?
			return;
		}
		
		return;
	}
	
	if (recordData == nil) {
		return;
	}
	
	uint16_t recordType = _AFNetworkServiceRecordTypeForRecordName(record);
	
	DNSRecordRef newRecord = NULL;
	DNSServiceErrorType newRecordError = DNSServiceAddRecord(_service, &newRecord, (DNSServiceFlags)0, recordType, (uint16_t)[recordData length], (const void *)[recordData bytes], 0);
	if (!_AFNetworkServicePublisherCheckAndForwardError(self, newRecordError)) {
		return;
	}
	
	NSMapInsert(self.recordToHandleMap, (const void *)record, (const void *)newRecord);
}

- (void)_addScope:(AFNetworkServiceScope *)scope {
	AFNetworkServiceScope *existingScope = [self.scopes member:scope];
	if (existingScope != nil) {
		return;
	}
	
	[self.scopes addObject:scope];
	
	if ([self.delegate respondsToSelector:@selector(networkServicePublisher:didPublishScope:)]) {
		[self.delegate networkServicePublisher:self didPublishScope:scope];
	}
}

- (void)_removeScope:(AFNetworkServiceScope *)scope {
	AFNetworkServiceScope *existingScope = [[[self.scopes member:scope] retain] autorelease];
	if (existingScope == nil) {
		return;
	}
	
	[self.scopes removeObject:existingScope];
	
	if ([self.delegate respondsToSelector:@selector(networkServicePublisher:didRemoveScope:)]) {
		[self.delegate networkServicePublisher:self didRemoveScope:existingScope];
	}
}

@end
