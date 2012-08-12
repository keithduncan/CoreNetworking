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
	
 */
@interface AFNetworkServiceScope : NSObject {
 @package
	uint32_t _interfaceIndex;
 @private
	NSString *_domain, *_type, *_name;
}

/*!
	\brief
	
 */
- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name;

/*!
	\brief
	
 */
@property (readonly, copy, nonatomic) NSString *domain;

/*!
	\brief
	
 */
@property (readonly, copy, nonatomic) NSString *type;

/*!
	\brief
	
 */
@property (readonly, copy, nonatomic) NSString *name;

/*!
	\brief
	
 */
- (BOOL)isEqualToScope:(AFNetworkServiceScope *)scope;

@end
