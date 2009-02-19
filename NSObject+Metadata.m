//
//  NSObject+Metadata.m
//  Timelines
//
//  Created by Keith Duncan on 11/10/2008.
//  Copyright 2008 thirty-three software. All rights reserved.
//

#import "NSObject+Metadata.h"

#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach-o/getsect.h>

#if TARGET_OS_MAC
static NSMapTable *_kBundleMetadataMap = nil;
#elif TARGET_OS_IPHONE
static NSMutableDictionary *_kBundleMetadataMap = nil;
#endif

static inline void *AFDataFromBundleExecutable(NSBundle *bundle, const char *segmentName, const char *sectionName, uint32_t *size) {
	assert(size != NULL);
	
	if (![bundle isLoaded]) [bundle load];
#warning experiment to determine if this is required
	
	void *data = NULL;
	uint32_t count = _dyld_image_count();
	
	for (uint32_t index = 0; index < count; index++) {
		if (strcmp([[bundle executablePath] fileSystemRepresentation], _dyld_get_image_name(index)) != 0) continue;
		
		intptr_t slide = _dyld_get_image_vmaddr_slide(index);
		
		const struct mach_header *header = _dyld_get_image_header(index);
		data = (void *)((intptr_t)getsectdatafromheader(header, segmentName, sectionName, size) + slide);
#warning this should consider 64 Bit headers
		
		break;
	}
	
	return data;
}

id af_class_getMetadataObjectForKey(Class class, NSString *key) {
	if (_kBundleMetadataMap == nil) {
#if TARGET_OS_MAC
		_kBundleMetadataMap = [[NSMapTable alloc] initWithKeyOptions:(NSPointerFunctionsObjectPersonality) valueOptions:(NSPointerFunctionsObjectPersonality) capacity:_dyld_image_count()];
#elif TARGET_OS_IPHONE
		_kBundleMetadataMap = [[NSMutableDictionary alloc] initWithCapacity:_dyld_image_count()];
#endif
	}
	
	NSBundle *classBundle = [NSBundle bundleForClass:class];
	
#if TARGET_OS_MAC
	NSDictionary *metadata = NSMapGet(_kBundleMetadataMap, [classBundle bundlePath]);
#elif TARGET_OS_IPHONE
	NSDictionary *metadata = [_kBundleMetadataMap objectForKey:[classBundle bundlePath]];
#endif
	
	if (metadata == nil) {
		uint32_t size = 0;
		void *data = AFDataFromBundleExecutable(classBundle, SEG_OBJC, "__class_metadata", &size);
#warning perhaps use mprotect to add another layer of protection around this data, though not storing it in XML would be a much greater step forward
		
		if (data == NULL) {
			[NSException raise:NSInvalidArgumentException format:@"%s, the bundle containing class %@ doesn't contain metadata.", __FUNCTION__, NSStringFromClass(class), nil];
			return nil;
		}
		
		NSData *rawMetadata = [NSData dataWithBytes:data length:size];
		metadata = [NSPropertyListSerialization propertyListFromData:rawMetadata mutabilityOption:(NSPropertyListMutabilityOptions)0 format:NULL errorDescription:NULL];
		
#if TARGET_OS_MAC
		NSMapInsert(_kBundleMetadataMap, [classBundle bundlePath], metadata);
#elif TARGET_OS_IPHONE
		[_kBundleMetadataMap setObject:metadata forKey:[classBundle bundlePath]];
#endif
	}
	
	id classMetadata = [metadata objectForKey:NSStringFromClass(class)];
	return (key != nil) ? [classMetadata objectForKey:key] : classMetadata;
}

@implementation NSObject (AFMetadata)

+ (id)metadata {
	return af_class_getMetadataObjectForKey(self, nil);
}

+ (id)metadataObjectForKey:(NSString *)key {
	return af_class_getMetadataObjectForKey(self, key);
}

@end
