//
//  AFKeyPathProxy.h
//  Key-Path Proxy
//
//  Created by Keith Duncan on 24/04/2009.
//  Copyright 2009 thirty-three. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*!
	@class
	@abstract	All messages are forwarded to the |currentTarget| using -valueForKey: with NSStringFromSelector() as the argument.
				The return value is used as the new |currentTarget| and self is returned.
				Once you've traversed the key path, you should extract the final object using the |currentTarget| property, this will apply any pending operators that don't require a second key to compute, such as @count.
	@discussion	The collection key-paths will be caught if the |currentTarget| is an array or set.
				This allows you to ask for -avg and will result in @avg being prepended to the next key-path component.
				
 */
@interface AFKeyPathProxy : NSObject {
	id _currentTarget;
	NSString *_prependOperator;
}

@property (retain) id currentTarget;

@end

@protocol AFKeyPathProxyCollectionOperators
- (id)avg;
- (id)count;
- (id)distinctUnionOfArrays;
- (id)distinctUnionOfObjects;
- (id)distinctUnionOfSets;
- (id)max;
- (id)min;
- (id)sum;
- (id)unionOfArrays;
- (id)unionOfObjects;
- (id)unionOfSets;
@end

@interface NSArray (AFKeyPathProxyAdditions) <AFKeyPathProxyCollectionOperators>
@end

@interface NSSet (AFKeyPathProxyAdditions) <AFKeyPathProxyCollectionOperators>
@end
