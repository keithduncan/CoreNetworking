//
//  AFNetworkServiceScope+AFNetworkPrivate.h
//  CoreNetworking
//
//  Created by Keith Duncan on 29/01/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFNetworkServiceScope.h"

@interface AFNetworkServiceScope (AFNetworkPrivate)

/*!
	\brief
	All labels are wildcard
 */
- (BOOL)_scopeDomainIsWildcard;

/*!
	\brief
	One label is wildcard
 */
- (BOOL)_scopeContainsWildcard;

@end
