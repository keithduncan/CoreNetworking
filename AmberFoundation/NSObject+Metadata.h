//
//  NSObject+Metadata.h
//  Timelines
//
//  Created by Keith Duncan on 11/10/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Foundation/Foundation.h>

#define AF_SECT_METADATA "__class_metadata"

/*!
	@detail	This function assumes that the provided bundle contains a Mach-O binary, the data is looked for in the primary executable.
			In order to map the section into memory, this function first loads the bundle if it hasn't been already.
 */
extern NSData *AFBundleSectionData(NSBundle *bundle, const char *segmentName, const char *sectionName);

/*!
	@detail	This function does NOT consider inheritance when looking up a value.
			It assumes the bundle containing the class implementation contains the required __OBJC,__class_metadata segment in the main executable.
			It will throw an exception of the [NSBundle bundleForClass:class] doesn't include the prerequsite metadata.
			If you pass nil for the key this returns the root metadata object.
 */
extern id af_class_getMetadataObjectForKey(Class classObject, const char *key);

@interface NSObject (AFMetadata)
+ (id)metadata;
+ (id)metadataObjectForKey:(NSString *)key;
@end
