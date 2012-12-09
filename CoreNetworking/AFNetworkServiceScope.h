//
//  AFNetworkServiceScope.h
//  CoreNetworking
//
//  Created by Keith Duncan on 12/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CoreNetworking/AFNetwork-Macros.h"

/*!
	\brief
	Wildcard field value, used to initialise a scope for browsing.
	Browse scopes must have at least one wildcard value, publish and resolve scopes must not have any wildcard values.
 */
AFNETWORK_EXTERN NSString *const AFNetworkServiceScopeWildcard;

/*!
	\brief
	Scope can include a wildcard to define a area of interest, or fully specify an individual service.
	
	This is the primitive type for all the DNS-SD integration.
 */
@interface AFNetworkServiceScope : NSObject {
 @package
	uint32_t _interfaceIndex;
 @private
	NSString *_domain, *_type, *_name;
}

/*!
	\brief
	Designated initialiser
 */
- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name;

extern NSString *const AFNetworkServiceScopeDomainKey;
/*!
	\brief
	Domain may be the local domain, registered and queried using multicast DNS, or a wide area domain.
 */
@property (readonly, copy, nonatomic) NSString *domain;

extern NSString *const AFNetworkServiceScopeTypeKey;
/*!
	\brief
	Suitable application and network layers can be inferred from the type
 */
@property (readonly, copy, nonatomic) NSString *type;

extern NSString *const AFNetworkServiceScopeNameKey;
/*!
	\brief
	Per service identifier
 */
@property (readonly, copy, nonatomic) NSString *name;

/*!
	\brief
	Compares the domain, type and name strings for equality.
 */
- (BOOL)isEqualToScope:(AFNetworkServiceScope *)scope;

/*!
	\brief
	Suitable for displaying in an interface
 */
@property (readonly, nonatomic) NSString *displayDescription;

@end
