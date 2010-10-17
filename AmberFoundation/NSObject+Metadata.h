//
//  NSObject+Metadata.h
//  Timelines
//
//  Created by Keith Duncan on 11/10/2008.
//  Copyright 2008. All rights reserved.
//

#import <Foundation/Foundation.h>

#define AF_SECT_METADATA "__class_metadata"

/*!
	\details
	Assumes that the provided bundle contains a Mach-O binary.
	The data is looked for in the bundle's primary executable.
	In order to map the section into memory, this function first loads the bundle if it hasn't been already.
	If loading fails, the function returns nil.
 */
extern NSData *AFBundleSectionData(NSBundle *bundle, const char *segmentName, const char *sectionName);

/*!
	\details
	Does NOT consider inheritance when looking up a value.
	It assumes the bundle containing the class implementation contains the required __OBJC,__class_metadata segment in the main executable.
	It will throw an exception of the [NSBundle bundleForClass:class] doesn't include the prerequsite metadata.
	If you pass nil for the key this returns the root metadata object.
 */
extern id af_class_getMetadataObjectForKey(Class classObject, const char *key);

@interface NSObject (AFMetadata)

/*!
	\return
	The root metadata object for the receiver.
 */
+ (id)metadata;

/*!
	\brief
	Assumes the root metadata object for the reciever is an NSDictionary.
 
	\return
	The result of sending <tt>-objectForKey:</tt> to the root metadata object for the receiver.
 */
+ (id)metadataObjectForKey:(NSString *)key;

@end
