//
//  AFNetworkServiceBrowser.m
//  CoreNetworking
//
//  Created by Keith Duncan on 12/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import "AFNetworkServiceBrowser.h"

#import <dns_sd.h>

#import "AFNetworkServiceScope.h"
#import "AFNetworkServiceScope+AFNetworkPrivate.h"
#import "AFNetworkServiceSource.h"
#import "AFNetworkSchedule.h"

#import "AFNetworkService-Functions.h"
#import "AFNetworkService-PrivateFunctions.h"
#import "AFNetwork-Constants.h"

// TODO: buffer batch add and remove operations, replaced the current delegate API with didFindScopes: didRemoveScopes: methods

#warning test browsing for a type with subtypes, and a specific subtype

struct _AFNetworkServiceBrowser_CompileTimeAssertions {
	char assert0[(sizeof(DNSServiceRef) <= sizeof(void *) ? 1 : -1)];
};

NSString *const AFNetworkServiceBrowserDomainBrowsable = @"*b";
NSString *const AFNetworkServiceBrowserDomainPublishable = @"*r";

@interface AFNetworkServiceBrowser ()
@property (readwrite, retain, nonatomic) AFNetworkServiceScope *serviceScope;

@property (retain, nonatomic) AFNetworkSchedule *schedule;

@property (assign, nonatomic) DNSServiceRef service;
@property (readwrite, retain, nonatomic) AFNetworkServiceSource *serviceSource;

@property (retain, nonatomic) NSMutableSet *scopes;
@property (retain, nonatomic) NSMapTable *scopeToBrowserMap;
@end

@interface AFNetworkServiceBrowser (Delegate) <AFNetworkServiceBrowserDelegate>

@end

@interface AFNetworkServiceBrowser (AFNetworkPrivate)
- (void)_copyEnvironmentToServiceBrowser:(AFNetworkServiceBrowser *)serviceBrowser;

- (BOOL)_scope:(AFNetworkServiceScope *)scope isEqual:(NSString *)domain :(NSString *)type :(NSString *)name;
- (BOOL)_scope:(AFNetworkServiceScope *)scope isEqualToScope:(AFNetworkServiceScope *)scope1;

- (BOOL)_scope:(AFNetworkServiceScope *)scope matches:(NSString *)domain :(NSString *)type :(NSString *)name;
- (BOOL)_scope:(AFNetworkServiceScope *)scope matchesPredicateScope:(AFNetworkServiceScope *)predicateScope;

- (void)_addBrowser:(AFNetworkServiceBrowser *)browser forScope:(AFNetworkServiceScope *)scope;

- (NSSet *)_filteredScopesUsingPredicate:(AFNetworkServiceScope *)predicateScope;

- (void)_addScope:(AFNetworkServiceScope *)scope;
- (void)_removeScope:(AFNetworkServiceScope *)scope;
@end

@implementation AFNetworkServiceBrowser

@synthesize serviceScope=_serviceScope;

@synthesize delegate=_delegate;

@synthesize service=_service, serviceSource=_serviceSource;

@synthesize scopes=_scopes, scopeToBrowserMap=_scopeToBrowserMap;

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_scopes = [[NSMutableSet alloc] init];
	_scopeToBrowserMap = [[NSMapTable alloc] initWithKeyOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality) valueOptions:(NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality) capacity:0];
	
	return self;
}

- (id)initWithServiceScope:(AFNetworkServiceScope *)serviceScope {
	NSParameterAssert([serviceScope _scopeContainsWildcard]);
	
	self = [self init];
	if (self == nil) return nil;
	
	_serviceScope = [serviceScope retain];
	
	return self;
}

- (void)dealloc {
	[_serviceScope release];
	
	[_schedule release];
	
	if (_service != NULL) {
		DNSServiceRefDeallocate(_service);
	}
	[_serviceSource release];
	
	[_scopes release];
	[_scopeToBrowserMap release];
	
	[super dealloc];
}

- (BOOL)_isScheduled {
	return (self.schedule != nil);
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode {
	NSParameterAssert(![self _isScheduled]);
	
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInRunLoop:runLoop forMode:mode];
	self.schedule = newSchedule;
}

- (void)scheduleInQueue:(dispatch_queue_t)queue {
	NSParameterAssert(![self _isScheduled]);
	
	AFNetworkSchedule *newSchedule = [[[AFNetworkSchedule alloc] init] autorelease];
	[newSchedule scheduleInQueue:queue];
	self.schedule = newSchedule;
}

static BOOL _AFNetworkServiceBrowserCheckAndForwardError(AFNetworkServiceBrowser *self, DNSServiceErrorType errorCode) {
	return _AFNetworkServiceCheckAndForwardError(self, self.delegate, @selector(networkServiceBrowser:didReceiveError:), errorCode);
}

static void _AFNetworkServiceBrowserEnumerateDomainsCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, char const *replyDomain, void *context) {
	AFNetworkServiceBrowser *self = [[(id)context retain] autorelease];
	
	if (![self.serviceSource isValid]) {
		return;
	}
	
	if (!_AFNetworkServiceBrowserCheckAndForwardError(self, errorCode)) {
		return;
	}
	
	NSString *domain = [NSString stringWithUTF8String:replyDomain];
	
	AFNetworkServiceScope *scope = [[[AFNetworkServiceScope alloc] initWithDomain:domain type:nil name:nil] autorelease];
	scope->_interfaceIndex = interfaceIndex;
	
	if ((flags & kDNSServiceFlagsAdd) == kDNSServiceFlagsAdd) {
		[self _addScope:scope];
	}
	else {
		[self _removeScope:scope];
	}
}

static void _AFNetworkServiceBrowserEnumerateTypesCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, char const *fullname, uint16_t rrtype, uint16_t rrclass, uint16_t rdlen, void const *rdata, uint32_t ttl, void *context) {
	AFNetworkServiceBrowser *self = [[(id)context retain] autorelease];
	
	if (![self.serviceSource isValid]) {
		return;
	}
	
	if (!_AFNetworkServiceBrowserCheckAndForwardError(self, errorCode)) {
		return;
	}
	
	AFNetworkServiceScope *parsedScope = _AFNetworkServiceBrowserParseEscapedRecord(rdlen, rdata);
	
	AFNetworkServiceScope *scope = [[[AFNetworkServiceScope alloc] initWithDomain:parsedScope.domain type:parsedScope.type name:nil] autorelease];
	scope->_interfaceIndex = interfaceIndex;
	
	if ((flags & kDNSServiceFlagsAdd) == kDNSServiceFlagsAdd) {
		[self _addScope:scope];
	}
	else {
		[self _removeScope:scope];
	}
}

static void _AFNetworkServiceBrowserEnumerateNamesCallback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex, DNSServiceErrorType errorCode, char const *replyName, char const *replyType, char const *replyDomain, void *context) {
	AFNetworkServiceBrowser *self = [[(id)context retain] autorelease];
	
	if (![self.serviceSource isValid]) {
		return;
	}
	
	if (!_AFNetworkServiceBrowserCheckAndForwardError(self, errorCode)) {
		return;
	}
	
	NSString *domain = [NSString stringWithUTF8String:replyDomain];
	NSString *type = [NSString stringWithUTF8String:replyType];
	NSString *name = [NSString stringWithUTF8String:replyName];
	
	AFNetworkServiceScope *scope = [[[AFNetworkServiceScope alloc] initWithDomain:domain type:type name:name] autorelease];
	scope->_interfaceIndex = interfaceIndex;
	
	if ((flags & kDNSServiceFlagsAdd) == kDNSServiceFlagsAdd) {
		[self _addScope:scope];
	}
	else {
		[self _removeScope:scope];
	}
}

- (void)searchForScopes {
	AFNetworkServiceScope *scope = self.serviceScope;
	NSParameterAssert(scope != nil);
	NSParameterAssert([self _isScheduled]);
	NSParameterAssert(self.delegate != nil);
	NSParameterAssert(self.service == NULL);
	
	DNSServiceRef newService = NULL;
	DNSServiceErrorType newServiceError = kDNSServiceErr_NoError;
	
	uint32_t interfaceIndex = kDNSServiceInterfaceIndexAny;
	
	if ([self _scope:scope isEqual:AFNetworkServiceBrowserDomainBrowsable :nil :nil] ||
		[self _scope:scope isEqual:AFNetworkServiceScopeWildcard :nil :nil]) {
		newServiceError = DNSServiceEnumerateDomains(&newService, kDNSServiceFlagsBrowseDomains, interfaceIndex, _AFNetworkServiceBrowserEnumerateDomainsCallback, self);
	}
	else if ([self _scope:scope isEqual:AFNetworkServiceBrowserDomainPublishable :nil :nil]) {
		newServiceError = DNSServiceEnumerateDomains(&newService, kDNSServiceFlagsRegistrationDomains, interfaceIndex, _AFNetworkServiceBrowserEnumerateDomainsCallback, self);
	}
	else if ((![scope.domain isEqualToString:AFNetworkServiceScopeWildcard] && [scope.type isEqualToString:AFNetworkServiceScopeWildcard] && scope.name == nil) ||
			 (![scope.domain isEqualToString:AFNetworkServiceScopeWildcard] && [scope.type isEqualToString:AFNetworkServiceScopeWildcard] && [scope.name isEqualToString:AFNetworkServiceScopeWildcard])) {
		NSString *fullname = nil;
		DNSServiceErrorType fullnameError = _AFNetworkServiceScopeFullname([[[AFNetworkServiceScope alloc] initWithDomain:scope.domain type:@"_services._dns-sd._udp." name:nil] autorelease], &fullname);
		if (!_AFNetworkServiceBrowserCheckAndForwardError(self, fullnameError)) {
			return;
		}
		
		newServiceError = DNSServiceQueryRecord(&newService, (DNSServiceFlags)0, interfaceIndex, [fullname UTF8String], kDNSServiceType_PTR, kDNSServiceClass_IN, _AFNetworkServiceBrowserEnumerateTypesCallback, self);
	}
	else if (( [scope.domain isEqualToString:AFNetworkServiceScopeWildcard] && ![scope.type isEqualToString:AFNetworkServiceScopeWildcard] && [scope.name isEqualToString:AFNetworkServiceScopeWildcard]) ||
			 (![scope.domain isEqualToString:AFNetworkServiceScopeWildcard] && ![scope.type isEqualToString:AFNetworkServiceScopeWildcard] && [scope.name isEqualToString:AFNetworkServiceScopeWildcard])) {
		char const *domain = NULL;
		if (![scope.domain isEqualToString:AFNetworkServiceScopeWildcard]) {
			domain = [scope.domain UTF8String];
		}
		
		char const *type = [scope.type UTF8String];
		
		newServiceError = DNSServiceBrowse(&newService, (DNSServiceFlags)0, interfaceIndex, type, domain, _AFNetworkServiceBrowserEnumerateNamesCallback, self);
	}
	else if ([self _scope:scope isEqual:AFNetworkServiceScopeWildcard :AFNetworkServiceScopeWildcard :nil] ||
			 [self _scope:scope isEqual:AFNetworkServiceScopeWildcard :AFNetworkServiceScopeWildcard :AFNetworkServiceScopeWildcard]) {
		AFNetworkServiceScope *browsableDomainsScope = [[[AFNetworkServiceScope alloc] initWithDomain:AFNetworkServiceBrowserDomainBrowsable type:nil name:nil] autorelease];
		AFNetworkServiceBrowser *domainBrowser = [[[AFNetworkServiceBrowser alloc] initWithServiceScope:browsableDomainsScope] autorelease];
		[self _addBrowser:domainBrowser forScope:scope];
		return;
	}
	
	if (!_AFNetworkServiceBrowserCheckAndForwardError(self, newServiceError)) {
		return;
	}
	
	if (newService == NULL) {
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"unknown scope configuration (%@)", scope] userInfo:nil];
		return;
	}
	self.service = newService;
	
	AFNetworkServiceSource *newServiceSource = _AFNetworkServiceSourceForSchedule(newService, self.schedule);
	self.serviceSource = newServiceSource;
	
	[newServiceSource resume];
}

- (void)invalidate {
	[[[self.scopeToBrowserMap objectEnumerator] allObjects] makeObjectsPerformSelector:@selector(invalidate)];
	[self.serviceSource invalidate];
}

@end

@implementation AFNetworkServiceBrowser (Delegate)

- (void)networkServiceBrowser:(AFNetworkServiceBrowser *)networkServiceBrowser didReceiveError:(NSError *)error {
	[self.delegate networkServiceBrowser:self didReceiveError:error];
}

- (void)networkServiceBrowser:(AFNetworkServiceBrowser *)networkServiceBrowser didDiscoverScope:(AFNetworkServiceScope *)scope {
	[self _addScope:scope];
}

- (void)networkServiceBrowser:(AFNetworkServiceBrowser *)networkServiceBrowser didRemoveScope:(AFNetworkServiceScope *)scope {
	[self _removeScope:scope];
}

@end

@implementation AFNetworkServiceBrowser (AFNetworkPrivate)

- (void)_copyEnvironmentToServiceBrowser:(AFNetworkServiceBrowser *)serviceBrowser {
	serviceBrowser.schedule = self.schedule;
}

- (BOOL)_scope:(AFNetworkServiceScope *)scope isEqual:(NSString *)domain :(NSString *)type :(NSString *)name {
	return [self _scope:scope isEqualToScope:[[[AFNetworkServiceScope alloc] initWithDomain:domain type:type name:name] autorelease]];
}

- (BOOL)_scope:(AFNetworkServiceScope *)scope isEqualToScope:(AFNetworkServiceScope *)scope1 {
	return [scope isEqualToScope:scope1];
}

- (BOOL)_scope:(AFNetworkServiceScope *)scope matches:(NSString *)domain :(NSString *)type :(NSString *)name {
	return [self _scope:scope matchesPredicateScope:[[[AFNetworkServiceScope alloc] initWithDomain:domain type:type name:name] autorelease]];
}

- (BOOL)_scope:(AFNetworkServiceScope *)scope matchesPredicateScope:(AFNetworkServiceScope *)predicateScope {
	BOOL predicateDomainIsWildcard = [predicateScope _scopeDomainIsWildcard];
	if (predicateDomainIsWildcard) {
		if (scope.domain == nil) {
			return NO;
		}
		if ([scope _scopeDomainIsWildcard]) {
			return NO;
		}
	}
	else if (predicateScope.domain == nil) {
		if (scope.domain != nil) {
			return NO;
		}
	}
	else if (![predicateScope.domain isEqualToString:scope.domain]) {
		return NO;
	}
	
	BOOL predicateTypeIsWildcard = [predicateScope.type isEqualToString:AFNetworkServiceScopeWildcard];
	if (predicateTypeIsWildcard) {
		if (scope.type == nil) {
			return NO;
		}
		if ([scope.type isEqualToString:AFNetworkServiceScopeWildcard]) {
			return NO;
		}
	}
	else if (predicateScope.type == nil) {
		if (scope.type !=  nil) {
			return NO;
		}
	}
	else if (![predicateScope.type isEqualToString:scope.type]) {
		return NO;
	}
	
	BOOL predicateNameIsWildcard = [predicateScope.name isEqualToString:AFNetworkServiceScopeWildcard];
	if (predicateNameIsWildcard) {
		if (scope.name == nil) {
			return NO;
		}
		if ([scope.name isEqualToString:AFNetworkServiceScopeWildcard]) {
			return NO;
		}
	}
	else if (predicateScope.name == nil) {
		if (scope.name != nil) {
			return NO;
		}
	}
	else if (![predicateScope.name isEqualToString:scope.name]) {
		return NO;
	}
	
	return YES;
}

- (void)_addBrowser:(AFNetworkServiceBrowser *)browser forScope:(AFNetworkServiceScope *)scope {
	[self.scopeToBrowserMap setObject:browser forKey:scope];
	
	[self _copyEnvironmentToServiceBrowser:browser];
	[browser setDelegate:self];
	
	[browser searchForScopes];
}

- (NSSet *)_filteredScopesUsingPredicate:(AFNetworkServiceScope *)predicateScope {
	NSSet *scopes = self.scopes;
	NSMutableSet *filteredScopes = [NSMutableSet setWithCapacity:[scopes count]];
	
	for (AFNetworkServiceScope *currentScope in scopes) {
		if (![self _scope:currentScope matchesPredicateScope:predicateScope]) {
			continue;
		}
		
		[filteredScopes addObject:currentScope];
	}
	
	return filteredScopes;
}

- (void)_addScope:(AFNetworkServiceScope *)scope {
	if (![self _scope:scope matchesPredicateScope:self.serviceScope]) {
		if ([self _scope:scope matches:AFNetworkServiceScopeWildcard :nil :nil]) {
			AFNetworkServiceScope *typesInDomainScope = [[[AFNetworkServiceScope alloc] initWithDomain:scope.domain type:AFNetworkServiceScopeWildcard name:nil] autorelease];
			AFNetworkServiceBrowser *typesInDomainBrowser = [[[AFNetworkServiceBrowser alloc] initWithServiceScope:typesInDomainScope] autorelease];
			[self _addBrowser:typesInDomainBrowser forScope:scope];
			return;
		}
		if ([self _scope:scope matches:AFNetworkServiceScopeWildcard :AFNetworkServiceScopeWildcard :nil]) {
			AFNetworkServiceScope *namesWithTypeInDomainScope = [[[AFNetworkServiceScope alloc] initWithDomain:scope.domain type:scope.type name:AFNetworkServiceScopeWildcard] autorelease];
			AFNetworkServiceBrowser *namesWithTypeInDomainBrowser = [[[AFNetworkServiceBrowser alloc] initWithServiceScope:namesWithTypeInDomainScope] autorelease];
			[self _addBrowser:namesWithTypeInDomainBrowser forScope:scope];
			return;
		}
		if ([self _scope:scope matches:AFNetworkServiceScopeWildcard :AFNetworkServiceScopeWildcard :AFNetworkServiceScopeWildcard]) {
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"can't browse for further scopes beyond an already fully specified scope" userInfo:nil];
			return;
		}
		return;
	}
	
	AFNetworkServiceScope *existingScope = [self.scopes member:scope];
	if (existingScope != nil) {
		return;
	}
	
	if ([self.delegate respondsToSelector:@selector(networkServiceBrowser:didDiscoverScope:)]) {
		[self.delegate networkServiceBrowser:self didDiscoverScope:scope];
	}
}

- (void)_removeScope:(AFNetworkServiceScope *)scope {
	if (![self _scope:scope matchesPredicateScope:self.serviceScope]) {
		AFNetworkServiceBrowser *serviceBrowser = [self.scopeToBrowserMap objectForKey:scope];
		[serviceBrowser invalidate];
		[self.scopeToBrowserMap removeObjectForKey:scope];
		
		NSMutableSet *removedScopes = [NSMutableSet set];
		[removedScopes unionSet:[self _filteredScopesUsingPredicate:[[[AFNetworkServiceScope alloc] initWithDomain:scope.domain type:AFNetworkServiceScopeWildcard name:AFNetworkServiceScopeWildcard] autorelease]]];
		[removedScopes unionSet:[self _filteredScopesUsingPredicate:[[[AFNetworkServiceScope alloc] initWithDomain:scope.domain type:AFNetworkServiceScopeWildcard name:nil] autorelease]]];
		for (AFNetworkServiceScope *currentScope in removedScopes) {
			[self _removeScope:currentScope];
		}
		return;
	}
	
	AFNetworkServiceScope *existingScope = [[[self.scopes member:scope] retain] autorelease];
	if (existingScope == nil) {
		return;
	}
	
	[self.scopes removeObject:existingScope];
	
	if ([self.delegate respondsToSelector:@selector(networkServiceBrowser:didRemoveScope:)]) {
		[self.delegate networkServiceBrowser:self didRemoveScope:existingScope];
	}
}

@end
