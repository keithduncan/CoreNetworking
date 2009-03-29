//
//  NSUserDefaults+Additions.m
//  Amber
//
//  Created by Keith Duncan on 17/10/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSUserDefaults+Additions.h"

@interface AFUserDefaultsDictionary : NSObject {
@public
	NSString *bundleIdentifier;
	NSMutableDictionary *dictionary;
}

@end

static NSMapTable *_observingDefaults = nil;

@implementation NSUserDefaults (AFAdditions)

+ (NSMutableDictionary *)persistentDomainForBundleIdentifier:(NSString *)bundleIdentifier {
	AFUserDefaultsDictionary *domain = [_observingDefaults objectForKey:bundleIdentifier];
	
	if (domain == nil) {
		domain = [[[AFUserDefaultsDictionary alloc] init] autorelease];
		domain->dictionary = [[[self standardUserDefaults] persistentDomainForName:bundleIdentifier] mutableCopy];
		domain->bundleIdentifier = [bundleIdentifier copy];
		
		[_observingDefaults setObject:domain forKey:bundleIdentifier];
	}
	
	return domain->dictionary;
}

@end

@implementation AFUserDefaultsDictionary

+ (void)initialize {
	NSUInteger options = (NSMapTableZeroingWeakMemory | NSMapTableObjectPointerPersonality);
	_observingDefaults = [[NSMapTable alloc] initWithKeyOptions:options valueOptions:options capacity:0];
}

- (void)dealloc {
	[[NSUserDefaults standardUserDefaults] setPersistentDomain:dictionary forName:bundleIdentifier];
	[_observingDefaults removeObjectForKey:bundleIdentifier];
	
	[dictionary release];
	[bundleIdentifier release];
	
	[super dealloc];
}

@end
