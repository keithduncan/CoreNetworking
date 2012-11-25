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
	NSString *domain = self.domain;
	return [domain isEqualToString:AFNetworkServiceScopeWildcard] || [domain isEqualToString:AFNetworkServiceBrowserDomainBrowsable] || [domain isEqualToString:AFNetworkServiceBrowserDomainPublishable];
}

- (BOOL)_scopeContainsWildcard {
	return [self _scopeDomainIsWildcard] || [self.type isEqualToString:AFNetworkServiceScopeWildcard] || [self.name isEqualToString:AFNetworkServiceScopeWildcard];
}

@end
