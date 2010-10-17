//
//  NSObject+Metadata.m
//  Timelines
//
//  Created by Keith Duncan on 11/10/2008.
//  Copyright 2008. All rights reserved.
//

#import "NSObject+Metadata.h"

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/getsect.h>

static NSMutableDictionary *_kBundleMetadataMap = nil;

NSData *AFBundleSectionData(NSBundle *bundle, const char *segmentName, const char *sectionName) {
	if (![bundle isLoaded]) {
		// Note: the bundle must be loaded to map the object files into memory
		BOOL didLoad = [bundle load];
		if (!didLoad) return nil;
	}
	
	uint32_t count = _dyld_image_count();
	for (uint32_t index = 0; index < count; index++) {
		if (strcmp([[bundle executablePath] fileSystemRepresentation], _dyld_get_image_name(index)) != 0) continue;
		
		intptr_t slide = _dyld_get_image_vmaddr_slide(index);
		
		// Note: since there's no mixed mode, every loaded bundle will be of the same word-width hence the function used can be word-width specific
		
#ifdef __LP64__
		// This warning has been filed under rdar://problem/6825431
		const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(index);
		
		uint64_t size = 0;
		void *data = (void *)((intptr_t)getsectdatafromheader_64(header, segmentName, sectionName, &size) + slide);
#else
		const struct mach_header *header = _dyld_get_image_header(index);
		
		uint32_t size = 0;
		void *data = (void *)((intptr_t)getsectdatafromheader(header, segmentName, sectionName,  &size) + slide);
#endif
		
		return [NSData dataWithBytesNoCopy:data length:size freeWhenDone:NO];
	}
	
	return nil;
}

id af_class_getMetadataObjectForKey(Class classObject, const char *key) {
	if (_kBundleMetadataMap == nil) {
		_kBundleMetadataMap = [[NSMutableDictionary alloc] initWithCapacity:_dyld_image_count()];
	}
	
	NSBundle *classBundle = [NSBundle bundleForClass:classObject];
	NSDictionary *metadata = [_kBundleMetadataMap objectForKey:[classBundle bundlePath]];
	
	if (metadata == nil) {
		NSData *rawMetadata = AFBundleSectionData(classBundle, SEG_OBJC, AF_SECT_METADATA);
		
		if (rawMetadata == nil) {
			[NSException raise:NSInvalidArgumentException format:@"%s, the bundle <%p> containing class %@ doesn't contain metadata.", __PRETTY_FUNCTION__, classBundle, NSStringFromClass(classObject), nil];
			return nil;
		}
		
		metadata = [NSPropertyListSerialization propertyListFromData:rawMetadata mutabilityOption:(NSPropertyListMutabilityOptions)0 format:NULL errorDescription:NULL];
		
		[_kBundleMetadataMap setObject:metadata forKey:[classBundle bundlePath]];
	}
	
	id classMetadata = [metadata objectForKey:NSStringFromClass(classObject)];
	return (key != NULL) ? [classMetadata objectForKey:[NSString stringWithUTF8String:key]] : classMetadata;
}

@implementation NSObject (AFMetadata)

+ (id)metadata {
	return af_class_getMetadataObjectForKey(self, nil);
}

+ (id)metadataObjectForKey:(NSString *)key {
	return af_class_getMetadataObjectForKey(self, [key UTF8String]);
}

@end
