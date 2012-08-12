//
//  AFNetworkServiceScope.m
//  CoreNetworking
//
//  Created by Keith Duncan on 12/10/2011.
//  Copyright (c) 2011 Keith Duncan. All rights reserved.
//

#import "AFNetworkServiceScope.h"

NSString *const AFNetworkServiceScopeWildcard = @"";

@implementation AFNetworkServiceScope

@synthesize domain=_domain, type=_type, name=_name;

- (id)initWithDomain:(NSString *)domain type:(NSString *)type name:(NSString *)name {
	self = [self init];
	if (self == nil) return nil;
	
	_domain = [domain copy];
	_type = [type copy];
	_name = [name copy];
	
	return self;
}

- (void)dealloc {
	[_domain release];
	[_type release];
	[_name release];
	
	[super dealloc];
}

- (BOOL)isEqual:(id)object {
	if (![object isKindOfClass:[AFNetworkServiceScope class]]) {
		return NO;
	}
	return [self isEqualToScope:(AFNetworkServiceScope *)object];
}

- (BOOL)isEqualToScope:(AFNetworkServiceScope *)scope {
	if ((self.domain == nil && scope.domain != nil) || (self.domain != nil && scope.domain == nil)) {
		return NO;
	}
	if (self.domain != nil && ![self.domain isEqualToString:scope.domain]) {
		return NO;
	}
	
	if ((self.type == nil && scope.type != nil) || (self.type != nil && scope.type == nil)) {
		return NO;
	}
	if (self.type != nil && ![self.type isEqualToString:scope.type]) {
		return NO;
	}
	
	if ((self.name == nil && scope.name != nil) || (self.name != nil && scope.name == nil)) {
		return NO;
	}
	if (self.name != nil && ![self.name isEqualToString:scope.name]) {
		return NO;
	}
	
	return YES;
}

- (NSString *)_partitionedFullName {
	NSString * (^correctLabel)(NSString *) = ^ NSString * (NSString *label) {
		if ([label isEqualToString:AFNetworkServiceScopeWildcard]) {
			label = @"*";
		}
		if (label == nil) {
			label = @"";
		}
		return [NSString stringWithFormat:@"<%@>", label];
	};
	return [NSString stringWithFormat:@"%@.%@.%@", correctLabel(self.name), correctLabel(self.type), correctLabel(self.domain)];
}

- (NSUInteger)hash {
	return [[self _partitionedFullName] hash];
}

- (NSString *)debugDescription {
	return [NSString stringWithFormat:@"<%@ %p> { %@ }", [self class], self, [self _partitionedFullName]];
}

@end
