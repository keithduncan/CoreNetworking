//
//  AFUserDefaults.h
//  iLog fitness
//
//  Created by Keith Duncan on 04/04/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

/*!
    @class
    @abstract    This class is a thin layer over the CFPreferences functions, it allows access to the preferences in a single application domain
    @discussion  It doesn't register for termination notifications nor does it save the values occasionally, this must be handled externally.
*/

@interface AFUserDefaults : NSObject {
	id _defaults;
	NSString *_identifier;
}

- (id)initWithBundleIdentifier:(NSString *)identifier;

@property(readonly, copy) NSString *identifier;

- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;

- (float)floatForKey:(NSString *)key;
- (void)setFloat:(float)value forKey:(NSString *)key;

- (double)doubleForKey:(NSString *)key;
- (void)setDouble:(double)value forKey:(NSString *)key;

- (BOOL)boolForKey:(NSString *)key;
- (void)setBool:(BOOL)value forKey:(NSString *)key;

- (NSInteger)integerForKey:(NSString *)key;
- (void)setInteger:(NSInteger)value forKey:(NSString *)key;

- (void)registerDefaults:(NSDictionary *)registrationDictionary;

- (NSDictionary *)dictionaryRepresentation;

- (BOOL)synchronize;

@end

@interface AFUserDefaults (Accessors)
- (NSString *)stringForKey:(NSString *)key;
- (NSArray *)arrayForKey:(NSString *)key;
- (NSDictionary *)dictionaryForKey:(NSString *)key;
- (NSData *)dataForKey:(NSString *)key;
@end
