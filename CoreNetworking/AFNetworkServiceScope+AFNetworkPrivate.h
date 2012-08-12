//
//  AFNetworkServiceScope+AFNetworkPrivate.h
//  CoreNetworking
//
//  Created by Keith Duncan on 29/01/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFNetworkServiceScope.h"

@interface AFNetworkServiceScope (AFNetworkPrivate)

- (BOOL)_scopeDomainIsWildcard;

- (BOOL)_scopeContainsWildcard;

@end
