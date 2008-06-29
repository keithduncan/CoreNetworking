//
//  KDUserDefaults.m
//  iLog fitness
//
//  Created by Keith Duncan on 04/04/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "KDUserDefaults.h"

#import <objc/runtime.h>
#import <CoreFoundation/CFPreferences.h>

#import "AmberFoundation/NSString+Additions.h"

static NSString *kKDBundleIdentifierDefaults = @"kIdentifierDefaults";
static NSString *kKDBundleRegisteredDefaults = @"kRegisteredDefaults";

@interface KDUserDefaults ()
@property(readwrite, copy) NSString *identifier;
@end

@interface KDUserDefaults (Private)
- (NSArray *)_searchList;
@end

@implementation KDUserDefaults

@synthesize identifier=_identifier;

static BOOL isPlistObject(id o) {
	if ([o isKindOfClass:[NSString class]]) return YES;
	else if ([o isKindOfClass:[NSData class]]) return YES;
	else if ([o isKindOfClass:[NSDate class]]) return YES;
	else if ([o isKindOfClass:[NSNumber class]]) return YES;
	else if ([o isKindOfClass:[NSArray class]]) {
		for (id currentObject in o) if (!isPlistObject(currentObject)) return NO;
		return YES;
    } else if ([o isKindOfClass:[NSDictionary class]]) {		
		for (id currentKey in o) if (![currentKey isKindOfClass:[NSString class]] || !isPlistObject([(NSDictionary *)o objectForKey:currentKey])) return NO;
		return YES;
    } else return NO;
}

static id TypedValueForKey(id self, SEL _cmd, NSString *key) {
	id value = [self objectForKey:key];
	return (isPlistObject(value) ? value : nil);
}

+ (void)initialize {
	if (self == [KDUserDefaults class]) {
		class_addMethod(self, @selector(stringForKey:), (IMP)TypedValueForKey, "@@:@");
		class_addMethod(self, @selector(arrayForKey:), (IMP)TypedValueForKey, "@@:@");
		class_addMethod(self, @selector(dictionaryForKey:), (IMP)TypedValueForKey, "@@:@");
		class_addMethod(self, @selector(dataForKey:), (IMP)TypedValueForKey, "@@:@");
		class_addMethod(self, @selector(stringArrayForKey:), (IMP)TypedValueForKey, "@@:@");
	}
}

- (id)init {
	[super init];
	
	_defaults = [[NSMutableDictionary alloc] init];
		
	return self;
}

- (id)initWithBundleIdentifier:(NSString *)identifier {
	if (identifier == nil || [identifier isEmpty]) {
		[NSException raise:NSInvalidArgumentException format:@"-[%@ %s], passed a nil or empty indentifer", NSStringFromClass([self class]), _cmd, nil];
		
		[self release];
		return nil;
	}
	
	[self init];
	
	self.identifier = identifier;
	
	CFArrayRef allKeys = CFPreferencesCopyKeyList((CFStringRef)_identifier, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	CFDictionaryRef values = CFPreferencesCopyMultiple(allKeys, (CFStringRef)_identifier, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	[_defaults setObject:(id)values forKey:kKDBundleIdentifierDefaults];
	CFRelease(values);
	
	return self;
}

- (void)dealloc {
	[_defaults release];
	self.identifier = nil;
	
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
	id oldValue = [self objectForKey:key];
	
	if (oldValue != nil && [oldValue isEqual:value]) return;
	else if (!isPlistObject(value)) [NSException raise:NSInvalidArgumentException format:@"-[%@ %s], %@ is not a valid plist object.", NSStringFromClass([self class]), _cmd, value];
	
	[[_defaults objectForKey:kKDBundleIdentifierDefaults] setObject:value forKey:key];
}

- (void)removeObjectForKey:(NSString *)key {
	[[_defaults objectForKey:kKDBundleIdentifierDefaults] removeObjectForKey:key];
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

- (void)registerDefaults:(NSDictionary *)registrationDictionary {
	[_defaults setObject:registrationDictionary forKey:kKDBundleRegisteredDefaults];
}

- (NSDictionary *)dictionaryRepresentation {
	NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
	
	for (NSDictionary *domain in [[self _searchList] reverseObjectEnumerator]) [defaults addEntriesFromDictionary:domain];
	
	return defaults;
}

- (BOOL)synchronize {
	NSDictionary *currentDefaults = [_defaults objectForKey:kKDBundleIdentifierDefaults];
	
	NSArray *newKeys = [currentDefaults allKeys];
	NSArray *savedKeys = (NSArray *)CFPreferencesCopyKeyList((CFStringRef)_identifier, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
	
	NSMutableSet *removedKeys = [NSMutableSet set];
	for (NSString *currentKey in savedKeys) if (![newKeys containsObject:currentKey]) [removedKeys addObject:currentKey];
	
	CFPreferencesSetMultiple((CFDictionaryRef)currentDefaults, (CFArrayRef)[removedKeys allObjects], (CFStringRef)_identifier, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
		
	return CFPreferencesSynchronize((CFStringRef)_identifier, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
}

@end

@implementation KDUserDefaults (Private)

- (NSArray *)_searchList {
	return  [NSArray arrayWithObjects:[_defaults objectForKey:kKDBundleIdentifierDefaults], [_defaults objectForKey:kKDBundleRegisteredDefaults], nil];
}

@end
