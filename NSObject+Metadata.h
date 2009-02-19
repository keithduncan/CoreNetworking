//
//  NSObject+Metadata.h
//  Timelines
//
//  Created by Keith Duncan on 11/10/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Note: This function does NOT consider inheritance when looking up a value
//	It assumes the bundle containing the class implementation contains the required __OBJC,__class_metadata segment in the main executable
//	If you pass nil for the key this returns the root metadata object

extern id af_class_getMetadataObjectForKey(Class class, NSString *key);

@interface NSObject (AFMetadata)

+ (id)metadata;
+ (id)metadataObjectForKey:(NSString *)key;

@end
