//
//  NSBundle+AFAdditions.h
//  Amber
//
//  Created by Keith Duncan on 10/01/2009.
//  Copyright 2009 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	@brief
	This constant is an Info.plist key for the company that produced a bundle.
 */
extern NSString *const AFCompanyNameKey;

@interface NSBundle (AFAdditions)

/*!
	@result <tt>-objectForInfoDictionaryKey:</tt> CFBundleVersion.
 */
- (NSString *)version;

/*!
	@result <tt>-objectForInfoDictionaryKey:</tt> CFBundleShortVersionString.
 */
- (NSString *)displayVersion;

/*!
	@result <tt>-objectForInfoDictionaryKey:</tt> CFBundleName.
 */
- (NSString *)name;

/*!
	@result <tt>-objectForInfoDictionaryKey:</tt> CFBundleDisplayName.
 */
- (NSString *)displayName;

/*!
	@result <tt>-objectForInfoDictionaryKey:</tt> AFCompanyName.
 */
- (NSString *)companyName;
@end

@interface NSBundle (AFPathAdditions)

- (NSString *)applicationSupportPath:(NSUInteger)searchDomain DEPRECATED_ATTRIBUTE;

/*!
	@brief
	This returns the application support path for the receiver. You should pass a domain
	suitable for <tt>NSSearchPathForDirectoriesInDomain</tt>. The full path is created by
	concatenating the search path at index zero, with the <tt>-[NSBundle name]</tt>.
 */
- (NSURL *)applicationSupportURL:(NSUInteger)searchDomain;

@end

/*!
	@brief
	This protocol allows classes to discover which bundle their resources have originated from.
	It accomodates for cases where <tt>+[NSBundle bundleForClass:]</tt> may not return an appropriate value.
 */
@protocol AFBundleDiscovery <NSObject>

- (NSBundle *)bundle;

@end
