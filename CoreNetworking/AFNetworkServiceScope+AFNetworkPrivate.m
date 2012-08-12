//
//  AFNetworkServiceScope+AFNetworkPrivate.m
//  CoreNetworking
//
//  Created by Keith Duncan on 29/01/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFNetworkServiceScope+AFNetworkPrivate.h"

#import "AFNetworkServiceBrowser.h"

@implementation AFNetworkServiceScope (AFNetworkPrivate)

- (BOOL)_scopeDomainIsWildcard {
	BOOL domainIsWildcard = NO;
	domainIsWildcard = (domainIsWildcard || [self.domain isEqualToString:AFNetworkServiceScopeWildcard]);
	domainIsWildcard = (domainIsWildcard || [self.domain isEqualToString:AFNetworkServiceBrowserDomainBrowsable]);
	domainIsWildcard = (domainIsWildcard || [self.domain isEqualToString:AFNetworkServiceBrowserDomainPublishable]);
	return domainIsWildcard;
}

- (BOOL)_scopeContainsWildcard {
	BOOL scopeContainsWildcard = NO;
	if (!scopeContainsWildcard) {
		scopeContainsWildcard = [self _scopeDomainIsWildcard];
	}
	if (!scopeContainsWildcard) {
		scopeContainsWildcard = [self.type isEqualToString:AFNetworkServiceScopeWildcard];
	}
	if (!scopeContainsWildcard) {
		scopeContainsWildcard = [self.name isEqualToString:AFNetworkServiceScopeWildcard];
	}
	return scopeContainsWildcard;
}

@end
