//
//  AFUserDefaults.m
//  Amber
//
//  Created by Keith Duncan on 04/04/2008.
//  Copyright 2008. All rights reserved.
//

#import "AFUserDefaults.h"

#if !TARGET_OS_IPHONE

#import <objc/runtime.h>
#import <CoreFoundation/CFPreferences.h>

#import "AFPropertyListProtocol.h"

#import "NSString+Additions.h"

NSString *const AFUserDefaultsDidChangeNotificationName = @"AFUserDefaultsDidChangeNotification";

static NSString *const kAFBundleIdentifierDefaults = @"kIdentifierDefaults";
static NSString *const kAFBundleRegisteredDefaults = @"kRegisteredDefaults";

@interface AFUserDefaults ()
@property (copy) NSDictionary *registrationDomain;
@end

@interface AFUserDefaults (Private)
- (NSArray *)_searchList;
- (BOOL)_synchronize;
- (void)_preferencesDidChange:(NSNotification *)notification;
@end

@implementation AFUserDefaults

@synthesize registrationDomain=_registration;
@synthesize identifier=_identifier;

static id TypedValueForKey(id self, SEL _cmd, NSString *key) {
	id value = [self objectForKey:key];
	return (AFObjectIsPlistSerialisable(value) ? value : nil);
}

+ (void)initialize {
	if (self != [AFUserDefaults class]) return;
	
	const char *typedMethodTypes = "@@:@";
	class_addMethod(self, @selector(stringForKey:), (IMP)TypedValueForKey, typedMethodTypes);
	class_addMethod(self, @selector(arrayForKey:), (IMP)TypedValueForKey, typedMethodTypes);
	class_addMethod(self, @selector(dictionaryForKey:), (IMP)TypedValueForKey, typedMethodTypes);
	class_addMethod(self, @selector(dataForKey:), (IMP)TypedValueForKey, typedMethodTypes);
	class_addMethod(self, @selector(stringArrayForKey:), (IMP)TypedValueForKey, typedMethodTypes);
}

- (id)initWithBundleIdentifier:(NSString *)identifier {
	NSParameterAssert((identifier != nil && ![identifier isEmpty]));
	
	self = [self init];
	if (self == nil) return nil;
	
	_identifier = [identifier copy];
	
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(_preferencesDidChange:) name:AFUserDefaultsDidChangeNotificationName object:self.identifier suspensionBehavior:NSNotificationSuspensionBehaviorHold];
	
	return self;
}

- (void)dealloc {
	[_registration release];
	[_identifier release];
	
	[super dealloc];
}

- (id)objectForKey:(NSString *)key {
	for (NSDictionary *domain in [self _searchList]) {
		id value = [domain objectForKey:key];
		if (value != nil) return value;
	}
	
	return nil;
}

- (void)setObject:(id)value forKey:(NSString *)key {
	NSAssert(AFObjectIsPlistSerialisable(value), @"value was not an object of plist type");
	CFPreferencesSetValue((CFStringRef)key, (CFPropertyListRef)value, (CFStringRef)self.identifier, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
}

- (void)removeObjectForKey:(NSString *)key {
	CFPreferencesSetValue((CFStringRef)key, (CFPropertyListRef)NULL, (CFStringRef)self.identifier, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
}

- (float)floatForKey:(NSString *)key {
	id value = [self objectForKey:key];
	return ([value respondsToSelector:@selector(floatValue)] ? [value floatValue] : 0.0);
}

- (void)setFloat:(float)value forKey:(NSString *)key {
	[self setObject:[NSNumber numberWithFloat:value] forKey:key];
}

- (double)doubleForKey:(NSString *)key {
	id value = [self objectForKey:key];
	return ([value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0.0);
}

- (void)setDouble:(double)value forKey:(NSString *)key {
	[self setObject:[NSNumber numberWithDouble:value] forKey:key];
}

- (BOOL)boolForKey:(NSString *)key {
	id value = [self objectForKey:key];
	return ([value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO);
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
	[self setObject:[NSNumber numberWithBool:value] forKey:key];
}

- (NSInteger)integerForKey:(NSString *)key {
	id value = [self objectForKey:key];
	return ([value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0);
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
	[self setObject:[NSNumber numberWithInteger:value] forKey:key];
}

- (NSUInteger)unsignedIntegerForKey:(NSString *)key {
	id value = [self objectForKey:key];
	return ([value respondsToSelector:@selector(unsignedIntegerValue)] ? [value unsignedIntegerValue] : 0);
}

- (void)setUnsignedInteger:(NSUInteger)value forKey:(NSString *)key {
	[self setObject:[NSNumber numberWithUnsignedInteger:value] forKey:key];
}

- (void)registerDefaults:(NSDictionary *)registrationDictionary {
	self.registrationDomain = registrationDictionary;
}

- (NSDictionary *)dictionaryValue {
	NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
	for (NSDictionary *domain in [[self _searchList] reverseObjectEnumerator]) [defaults addEntriesFromDictionary:domain];
	return defaults;
}

- (BOOL)synchronize {
	BOOL result = [self _synchronize];
	
	if (result)
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:AFUserDefaultsDidChangeNotificationName object:self.identifier userInfo:nil options:0];
	
	return result;
}

@end

@implementation AFUserDefaults (Private)

- (NSArray *)_searchList {
	CFArrayRef keys = CFPreferencesCopyKeyList((CFStringRef)self.identifier, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	CFDictionaryRef defaults = CFPreferencesCopyMultiple(keys, (CFStringRef)self.identifier, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	
	NSArray *searchList = [NSArray arrayWithObjects:(id)defaults, self.registrationDomain, nil];
	
	CFRelease(defaults);
	CFRelease(keys);
	
	return searchList;
}

- (BOOL)_synchronize {	
	return CFPreferencesSynchronize((CFStringRef)self.identifier, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
}

- (void)_preferencesDidChange:(NSNotification *)notification {
	if (![[notification object] isEqualToString:self.identifier]) return;
	
	[self _synchronize];
}

@end

#endif
