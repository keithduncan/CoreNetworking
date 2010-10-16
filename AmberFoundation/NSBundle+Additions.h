//
//  NSBundle+AFAdditions.h
//  Amber
//
//  Created by Keith Duncan on 10/01/2009.
//  Copyright 2009 software. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
	\file
 */

@interface NSBundle (AFAdditions)

/*!
	\return
	<tt>-objectForInfoDictionaryKey:</tt> CFBundleVersion.
 */
- (NSString *)version;

/*!
	\brief
	This method will fallback on <tt>-version</tt> before returning nil.
 
	\return
	<tt>-objectForInfoDictionaryKey:</tt> CFBundleShortVersionString.
 */
- (NSString *)displayVersion;

/*!
	\return
	<tt>-objectForInfoDictionaryKey:</tt> CFBundleName.
 */
- (NSString *)name;

/*!
	\brief
	This method will fallback on <tt>-name</tt> before returning nil.
 
	\return
	<tt>-objectForInfoDictionaryKey:</tt> CFBundleDisplayName.
 */
- (NSString *)displayName;

@end

@interface NSBundle (AFPathAdditions)

/*!
	\brief
	This returns the application support path for the receiver. You should pass a domain
	suitable for <tt>NSSearchPathForDirectoriesInDomain</tt>. The full path is created by
	concatenating the search path at index zero, with the <tt>-[NSBundle name]</tt>.
 */
- (NSURL *)applicationSupportURL:(NSUInteger)searchDomain;

@end

/*!
	\brief
	This protocol allows classes to discover which bundle their resources have originated from.
	It accommodates for cases where <tt>+[NSBundle bundleForClass:]</tt> may not return an appropriate value.
 */
@protocol AFBundleDiscovery <NSObject>

- (NSBundle *)bundle;

@end
