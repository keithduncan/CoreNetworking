//
//  AFUserDefaults.h
//  Amber
//
//  Created by Keith Duncan on 04/04/2008.
//  Copyright 2008 thirty-three. All rights reserved.
//

#import <Foundation/Foundation.h>

#if !TARGET_OS_IPHONE

/*!
	@brief
	This class is essentailly NSUserDefaults for an arbitary bundle identifer, it doesn't
	restrict you to working with the current application identifer.
	
	@detail
	It doesn't register for termination notifications nor does it save the 
	values occasionally, this must be handled externally. It does propogate 
	synchronization notifications like NSUserDefaults does. This is particularly 
	useful for plugin defaults, used across process boundaries.
*/
@interface AFUserDefaults : NSObject {
	NSString *_identifier;
	id _registration;
}

/*!
	@brief
	This is the bundle identifer provided at instantiation time.
 */
@property (readonly, copy) NSString *identifier;

/*!
	@brief
	Designated Initialiser.
 */
- (id)initWithBundleIdentifier:(NSString *)identifier;

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

- (NSUInteger)unsignedIntegerForKey:(NSString *)key;
- (void)setUnsignedInteger:(NSUInteger)value forKey:(NSString *)key;

/*!
	@brief
	This is inserted at the lowest index of the search list, the values will
	only be returned if the default domains above it don't contain an object for requested key.
 
	@param	|regisrationDictionary| is copied.
 */
- (void)registerDefaults:(NSDictionary *)registrationDictionary;

- (NSDictionary *)dictionaryValue;

- (BOOL)synchronize;

@end

/*!
	@brief
	These are simply strongly typed synonyms to <tt>-objectForKey:</tt>.
 */
@interface AFUserDefaults (TypedAccessors)
- (NSString *)stringForKey:(NSString *)key;
- (NSArray *)arrayForKey:(NSString *)key;
- (NSDictionary *)dictionaryForKey:(NSString *)key;
- (NSData *)dataForKey:(NSString *)key;
@end

#endif
