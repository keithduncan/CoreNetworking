//
//  AFNetworkServiceResolver.m
//  CoreNetworking
//
//  Created by Keith Duncan on 12/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import "AFNetworkServiceResolver.h"

#import <sys/socket.h>
#import <dns_sd.h>

#import "AFNetworkServiceScope.h"
#import "AFNetworkServiceScope+AFNetworkPrivate.h"

#import "AFNetworkService-Functions.h"
#import "AFNetworkService-PrivateFunctions.h"

#import "AFNetwork-Constants.h"

static BOOL _AFNetworkServiceResolverCheckAndForwardError(AFNetworkServiceResolver *self, DNSServiceErrorType errorCode) {
	return AFNetworkServiceCheckAndForwardError(self, self.delegate, @selector(networkServiceResolver:didReceiveError:), errorCode);
}

@interface AFNetworkServiceResolver ()
@property (retain, nonatomic) AFNetworkServiceScope *serviceScope;

@property (retain, nonatomic) NSMapTable *recordToQueryServiceMap;
@property (assign, nonatomic) DNSServiceRef resolveService, getInfoService;

@property (retain, nonatomic) NSMapTable *serviceToServiceSourceMap;

@property (retain, nonatomic) NSMapTable *recordToDataMap;
@end

@interface AFNetworkServiceResolver (AFNetworkPrivate)
- (AFNetworkServiceSource *)_serviceSourceForService:(DNSServiceRef)service;
- (void)_addServiceSourceForService:(DNSServiceRef)service;
- (void)_removeServiceSourceForService:(DNSServiceRef)service;

- (void)_scheduleTimerWithTimeout:(NSTimeInterval)timeout;
- (void)_unscheduleTimer;
- (BOOL)_timerIsValid;
- (void)_resolveDidTimeout;
@end

@implementation AFNetworkServiceResolver

@synthesize serviceScope=_serviceScope;

@synthesize delegate=_delegate;

@synthesize recordToQueryServiceMap=_recordToQueryServiceMap, resolveService=_resolveService, getInfoService=_getInfoService;

@synthesize serviceToServiceSourceMap=_serviceToServiceSourceMap;

@synthesize recordToDataMap=_recordToDataMap;
@synthesize addresses=_addresses;

- (id)initWithServiceScope:(AFNetworkServiceScope *)serviceScope {
	NSParameterAssert(![serviceScope _scopeContainsWildcard]);
	
	self = [self init];
	if (self == nil) return nil;
	
	_serviceScope = [serviceScope retain];
	
	NSPointerFunctionsOptions recordToMapKeyOptions = (NSPointerFunctionsOpaqueMemory | NSPointerFunctionsIntegerPersonality);
	NSPointerFunctionsOptions recordToObjectMapObjectOptions = (NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality);
	
	_recordToQueryServiceMap = [[NSMapTable alloc] initWithKeyOptions:recordToMapKeyOptions valueOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality) capacity:0];
	_serviceToServiceSourceMap = [[NSMapTable alloc] initWithKeyOptions:recordToMapKeyOptions valueOptions:recordToObjectMapObjectOptions capacity:0];
	_recordToDataMap = [[NSMapTable alloc] initWithKeyOptions:recordToMapKeyOptions valueOptions:recordToObjectMapObjectOptions capacity:0];
	
	return self;
}

- (void)dealloc {
	[_serviceScope release];
	
	_AFNetworkServiceSourceEnvironmentCleanup((_AFNetworkServiceSourceEnvironment *)&_sources);
	
	[self invalidate];
	[_serviceToServiceSourceMap release];
	
	NSMapEnumerator recordToQueryMapEnumerator = NSEnumerateMapTable(_recordToQueryServiceMap);
	AFNetworkServiceRecordType recordType = 0; DNSServiceRef queryService = NULL;
	while (NSNextMapEnumeratorPair(&recordToQueryMapEnumerator, (void **)&recordType, (void **)&queryService)) {
		DNSServiceRefDeallocate(queryService);
	}
	[_recordToQueryServiceMap release];
	
	[(id)_timers._runLoopTimer release];
	if (_timers._dispatchTimer != NULL) {
		dispatch_source_cancel(_timers._dispatchTimer);
		dispatch_release(_timers._dispatchTimer);
	}
	
	if (_resolveService != NULL) {
		DNSServiceRefDeallocate(_resolveService);
	}
	if (_getInfoService != NULL) {
		DNSServiceRefDeallocate(_getInfoService);
	}
	
	[_recordToDataMap release];
	[_addresses release];
	
	[super dealloc];
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	_AFNetworkServiceSourceEnvironmentScheduleInRunLoop((_AFNetworkServiceSourceEnvironment *)&_sources, runLoop, mode);
}

- (void)unscheduleFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	_AFNetworkServiceSourceEnvironmentUnscheduleFromRunLoop((_AFNetworkServiceSourceEnvironment *)&_sources, runLoop, mode);
}

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	_AFNetworkServiceSourceEnvironmentScheduleInQueue((_AFNetworkServiceSourceEnvironment *)&_sources, queue);
}

static void _AFNetworkServiceResolverQueryRecordCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, char const *fullname, uint16_t rrtype, uint16_t rrclass, uint16_t rdlen, void const *rdata, uint32_t ttl, void *context) {
	AFNetworkServiceResolver *self = [[(id)context retain] autorelease];
	
	if (![[self _serviceSourceForService:sdRef] isValid]) {
		return;
	}
	
	if (!_AFNetworkServiceResolverCheckAndForwardError(self, errorCode)) {
		return;
	}
	
	AFNetworkServiceRecordType record = _AFNetworkServiceRecordNameForRecordType(rrtype);
	
	NSData *recordData = [NSData dataWithBytes:rdata length:rdlen];
	NSMapInsert(self.recordToDataMap, (void const *)record, (void const *)recordData);
	
	if ([self.delegate respondsToSelector:@selector(networkServiceResolver:didUpdateRecord:withData:)]) {
		[self.delegate networkServiceResolver:self didUpdateRecord:record withData:recordData];
	}
}

- (void)addMonitorForRecord:(AFNetworkServiceRecordType)record {
	AFNetworkServiceScope *scope = self.serviceScope;
	NSParameterAssert(scope != nil);
	NSParameterAssert(_sources._runLoopSource != NULL || _sources._dispatchSource != NULL);
	
	DNSServiceRef existingRecordQuery = NSMapGet(self.recordToQueryServiceMap, (void const *)record);
	if (existingRecordQuery != NULL) {
		return;
	}
	
	NSString *fullname = nil;
	DNSServiceErrorType fullnameError = _AFNetworkServiceScopeFullname(scope, &fullname);
	if (!_AFNetworkServiceResolverCheckAndForwardError(self, fullnameError)) {
		return;
	}
	
	uint16_t recordType = _AFNetworkServiceRecordTypeForRecordName(record);
	
	DNSServiceRef newRecordQueryService = NULL;
	DNSServiceErrorType newRecordQueryError = DNSServiceQueryRecord(&newRecordQueryService, (DNSServiceFlags)0, scope->_interfaceIndex, [fullname UTF8String], recordType, kDNSServiceClass_IN, _AFNetworkServiceResolverQueryRecordCallback, self);
	if (!_AFNetworkServiceResolverCheckAndForwardError(self, newRecordQueryError)) {
		return;
	}
	NSMapInsert(self.recordToQueryServiceMap, (void const *)record, (void const *)newRecordQueryService);
	
	[self _addServiceSourceForService:newRecordQueryService];
}

- (void)removeMonitorForRecord:(AFNetworkServiceRecordType)record {
	DNSServiceRef existingRecordQuery = NSMapGet(self.recordToQueryServiceMap, (void const *)record);
	if (existingRecordQuery == NULL) {
		return;
	}
	
	[self _removeServiceSourceForService:existingRecordQuery];
	
	DNSServiceRefDeallocate(existingRecordQuery);
	NSMapRemove(self.recordToQueryServiceMap, (void const *)record);
}

- (NSData *)dataForRecord:(AFNetworkServiceRecordType)record {
	return NSMapGet(self.recordToDataMap, (void const *)record);
}

static void _AFNetworkServiceResolverGetAddrInfoCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, char const *hostname, struct sockaddr const *address, uint32_t ttl, void *context) {
	AFNetworkServiceResolver *self = [[(id)context retain] autorelease];
	
	if (![[self _serviceSourceForService:sdRef] isValid]) {
		return;
	}
	
	if (!_AFNetworkServiceResolverCheckAndForwardError(self, errorCode)) {
		return;
	}
	
	NSData *addressValue = [NSData dataWithBytes:address length:address->sa_len];
	
	NSMutableArray *addresses = self->_addresses;
	if (addresses == nil) {
		self->_addresses = addresses = [[NSMutableArray alloc] init];
	}
	
	[addresses addObject:addressValue];
	[self _unscheduleTimer];
	
	if ([self.delegate respondsToSelector:@selector(networkServiceResolver:didResolveAddress:)]) {
		[self.delegate networkServiceResolver:self didResolveAddress:addressValue];
	}
}

static void _AFNetworkServiceResolverResolveCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, char const *fullname, char const *hostname, uint16_t port, uint16_t txtLen, unsigned char const *txtRecord, void *context) {
	AFNetworkServiceResolver *self = [[(id)context retain] autorelease];
	
	if (![[self _serviceSourceForService:sdRef] isValid]) {
		return;
	}
	
	if (!_AFNetworkServiceResolverCheckAndForwardError(self, errorCode)) {
		return;
	}
	
	__unused uint16_t hostPort = ntohs(port);
	
	DNSServiceRef getInfoService = NULL;
	DNSServiceErrorType getInfoServiceError = DNSServiceGetAddrInfo(&getInfoService, (DNSServiceFlags)0, interfaceIndex, (DNSServiceProtocol)0, hostname, _AFNetworkServiceResolverGetAddrInfoCallback, self);
	if (!_AFNetworkServiceResolverCheckAndForwardError(self, getInfoServiceError)) {
		goto SharedTeardown;
	}
	
	self.getInfoService = getInfoService;
	[self _addServiceSourceForService:getInfoService];
	
SharedTeardown:;
	[self _removeServiceSourceForService:self->_resolveService];
	DNSServiceRefDeallocate(self->_resolveService);
	self->_resolveService = NULL;
}

- (void)resolveWithTimeout:(NSTimeInterval)timeout {
	AFNetworkServiceScope *scope = self.serviceScope;
	NSParameterAssert(scope != nil);
	NSParameterAssert(_sources._runLoopSource != NULL || _sources._dispatchSource != NULL);
	
	if (_resolveService != NULL) {
		return;
	}
	
	DNSServiceRef resolveService = NULL;
	DNSServiceErrorType resolveServiceError = DNSServiceResolve(&resolveService, (DNSServiceFlags)0, scope->_interfaceIndex, [scope.name UTF8String], [scope.type UTF8String], [scope.domain UTF8String], _AFNetworkServiceResolverResolveCallback, self);
	if (!_AFNetworkServiceResolverCheckAndForwardError(self, resolveServiceError)) {
		return;
	}
	
	self.resolveService = resolveService;
	[self _addServiceSourceForService:resolveService];
	
	[self _scheduleTimerWithTimeout:timeout];
}

- (NSArray *)addresses {
	return [[_addresses copy] autorelease];
}

- (void)invalidate {
	[[[self.serviceToServiceSourceMap objectEnumerator] allObjects] makeObjectsPerformSelector:@selector(invalidate)];
}

@end

@implementation AFNetworkServiceResolver (AFNetworkPrivate)

- (AFNetworkServiceSource *)_serviceSourceForService:(DNSServiceRef)service {
	return NSMapGet(self.serviceToServiceSourceMap, (void const *)service);
}

- (void)_addServiceSourceForService:(DNSServiceRef)service {
	AFNetworkServiceSource *newServiceSource = _AFNetworkServiceSourceEnvironmentServiceSource(service, (_AFNetworkServiceSourceEnvironment *)&_sources);
	NSMapInsert(self.serviceToServiceSourceMap, (void const *)service, (void const *)newServiceSource);
}

- (void)_removeServiceSourceForService:(DNSServiceRef)service {
	AFNetworkServiceSource *serviceSource = [self _serviceSourceForService:service];
	[serviceSource invalidate];
	NSMapRemove(self.serviceToServiceSourceMap, (void const *)service);
}

- (void)_scheduleTimerWithTimeout:(NSTimeInterval)timeout {
	if (timeout == -1) {
		timeout = 60.;
	}
	if (timeout <= 0) {
		return;
	}
	
	if (_sources._runLoopSource != NULL) {
		NSTimer *resolveTimeout = [[NSTimer alloc] initWithFireDate:[[NSDate date] dateByAddingTimeInterval:timeout] interval:0 target:self selector:@selector(_resolveDidTimeout) userInfo:nil repeats:NO];
		
		NSDictionary *runLoopEnvironment = _sources._runLoopSource;
		[[runLoopEnvironment objectForKey:@"RunLoop"] addTimer:resolveTimeout forMode:[runLoopEnvironment objectForKey:@"Mode"]];
		
		_timers._runLoopTimer = resolveTimeout;
	}
	else if (_sources._dispatchSource != NULL) {
		dispatch_queue_t dispatchQueue = _sources._dispatchSource;
		dispatch_source_t dispatchTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatchQueue);
		dispatch_source_set_event_handler(dispatchTimer, ^ {
#warning this shouldn't be a strong reference
			[self _resolveDidTimeout];
		});
		dispatch_source_set_timer(dispatchTimer, DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC, 0);
		dispatch_resume(dispatchTimer);
		_timers._dispatchTimer = dispatchTimer;
	}
	else {
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"unsupported scheduling environment, cannot set up resolve timeout" userInfo:nil];
	}
}

- (void)_unscheduleTimer {
	if (_timers._runLoopTimer != nil) {
		[(id)_timers._runLoopTimer invalidate];
	}
	if (_timers._dispatchTimer != NULL) {
		dispatch_source_cancel(_timers._dispatchTimer);
	}
}

- (BOOL)_timerIsValid {
	if (_timers._runLoopTimer != nil) {
		return [(id)_timers._runLoopTimer isValid];
	}
	if (_timers._dispatchTimer != NULL) {
		return (dispatch_source_testcancel(_timers._dispatchTimer) == 0);
	}
	return NO;
}

- (void)_resolveDidTimeout {
	if (![self _timerIsValid]) {
		return;
	}
	
	if (self.resolveService != NULL) {
		[self _removeServiceSourceForService:self.resolveService];
		
		DNSServiceRefDeallocate(self.resolveService);
		self.resolveService = NULL;
	}
	if (self.getInfoService != NULL) {
		[self _removeServiceSourceForService:self.getInfoService];
		
		DNSServiceRefDeallocate(self.getInfoService);
		self.getInfoService = NULL;
	}
	
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
#warning complete this error
							   nil];
	NSError *error = [NSError errorWithDomain:AFCoreNetworkingBundleIdentifier code:AFNetworkErrorUnknown userInfo:errorInfo];
	
	[self.delegate networkServiceResolver:self didReceiveError:error];
}

@end
